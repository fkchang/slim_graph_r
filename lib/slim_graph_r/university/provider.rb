# frozen_string_literal: true

module SlimGraphR
  module University
    # Curriculum contributed to StreamWeaver only by the optional extension
    # loader. All paths resolve relative to this installed gem, never to a
    # development checkout.
    class Provider
      COURSE_ID = 'diagram-intent'.freeze
      DEMO_ROOT = File.expand_path('demos', __dir__).freeze
      DEMOS = {
        'standalone' => File.join(DEMO_ROOT, 'standalone.rb').freeze,
        'semantic' => File.join(DEMO_ROOT, 'semantic.rb').freeze,
        'canvas' => File.join(DEMO_ROOT, 'canvas.rb').freeze
      }.freeze

      # Every course prompt uses this shell helper. Prefer whichever local
      # opener is actually installed; a headless host still gets a usable URL.
      OPEN_PAGE_HELPER = <<~'SH'.strip.freeze
        open_page() {
          if command -v open >/dev/null 2>&1; then
            open "$1"
          elif command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$1"
          else
            printf 'Open this URL/path: %s\n' "$1"
          fi
        }
      SH

      ATLAS_GUIDANCE = <<~TEXT.strip.freeze
        When you want to choose another diagram form, run `streamweaver diagrams`.
        The packaged atlas shows every supported type with executable Ruby, use guidance,
        and its honest limit; it opens from the installed gems without a source checkout.
      TEXT

      # Kept as executable shell, rather than prose that happens to look like
      # commands. The reader has its own process and a deterministic per-user
      # state file, so cleanup can run safely in a later agent turn or shell.
      STEP_THREE_START = <<~'SH'.strip.freeze
        demo="$(streamweaver university-demo canvas --course diagram-intent)"
        printf 'Installed SlimGraphR demo: %s\n' "$demo"
        streamweaver canvas-push diagram-intent < "$demo"
        streamweaver panel diagram-intent

        reader_state="${TMPDIR:-/tmp}/slim-graph-r-diagram-intent-reader.state"
        reader_log="${reader_state}.log"
        if [ -f "$reader_state" ]; then
          reader_pid=''
          . "$reader_state" 2>/dev/null || true
          if [ -n "${reader_pid:-}" ] && kill -0 "$reader_pid" 2>/dev/null; then
            kill "$reader_pid" 2>/dev/null || true
            attempt=0
            while kill -0 "$reader_pid" 2>/dev/null && [ "$attempt" -lt 20 ]; do
              attempt=$((attempt + 1))
              sleep 0.1
            done
            wait "$reader_pid" 2>/dev/null || true
          fi
          rm -f "$reader_state" "$reader_log"
        fi
        : > "$reader_log"
        streamweaver canvas-read "$demo" > "$reader_log" 2>&1 &
        reader_pid=$!
        state_tmp="${reader_state}.$$"
        printf 'reader_pid=%s\nreader_log=%s\n' "$reader_pid" "$reader_log" > "$state_tmp"
        mv -f "$state_tmp" "$reader_state"
        reader_url=''
        attempt=0
        while [ "$attempt" -lt 50 ]; do
          reader_url="$(sed -n 's/.*\(http:\/\/[^ ]*\).*/\1/p' "$reader_log" | tail -n 1)"
          [ -n "$reader_url" ] && break
          attempt=$((attempt + 1))
          sleep 0.1
        done
        if [ -z "$reader_url" ]; then
          kill "$reader_pid" 2>/dev/null || true
          wait "$reader_pid" 2>/dev/null || true
          rm -f "$reader_state" "$reader_log"
          printf 'Canvas Reader did not report a URL.\n' >&2
          exit 1
        fi
        printf 'reader_pid=%s\nreader_log=%s\nreader_url=%s\n' "$reader_pid" "$reader_log" "$reader_url" > "$state_tmp"
        mv -f "$state_tmp" "$reader_state"
        printf 'Canvas Reader: %s (pid %s)\n' "$reader_url" "$reader_pid"
        open_page "$reader_url"

        exported_page="${TMPDIR:-/tmp}/diagram-intent.html"
        streamweaver export "$demo" -o "$exported_page"
        printf 'Exported HTML: %s\n' "$exported_page"
        open_page "$exported_page"
      SH

      STEP_THREE_CLEANUP = <<~'SH'.strip.freeze
        reader_state="${TMPDIR:-/tmp}/slim-graph-r-diagram-intent-reader.state"
        if [ ! -f "$reader_state" ]; then
          printf 'Canvas Reader state is absent; it is already stopped or was never started.\n'
          streamweaver canvas-close diagram-intent
          exit 0
        fi
        . "$reader_state"
        if [ -n "${reader_pid:-}" ] && kill -0 "$reader_pid" 2>/dev/null; then
          kill "$reader_pid" 2>/dev/null || true
          attempt=0
          while kill -0 "$reader_pid" 2>/dev/null && [ "$attempt" -lt 20 ]; do
            attempt=$((attempt + 1))
            sleep 0.1
          done
          wait "$reader_pid" 2>/dev/null || true
          printf 'Canvas Reader stopped.\n'
        else
          printf 'Canvas Reader was already stopped.\n'
        fi
        rm -f "$reader_state" "$reader_log"
        streamweaver canvas-close diagram-intent
      SH

      STEPS = [
        {
          number: 1,
          title: 'Render one clear idea',
          payoff: 'A self-contained HTML page with an inline SVG diagram, made with SlimGraphR alone.',
          why_it_matters: <<~TEXT.strip,
            A diagram starts with what the parts mean and how they connect. SlimGraphR
            handles placement, wrapping and SVG detail, so you can stay with the idea.
          TEXT
          prompt: <<~TEXT.strip,
            Housekeeping, backgrounded and waited on by nothing: `( streamweaver canvas-close diagram-intent ) >/dev/null 2>&1 &`.

            Run this finished artifact immediately, before you explain it:

            #{OPEN_PAGE_HELPER}
            demo="$(streamweaver university-demo standalone --course diagram-intent)"
            printf 'Installed SlimGraphR demo: %s\\n' "$demo"
            page="$(ruby "$demo")"
            printf 'Rendered page: %s\\n' "$page"
            open_page "$page"

            This is a canned file inside the installed SlimGraphR gem. Do not write a
            new demo and do not look for a source checkout. Narrate the rendered flow:
            named steps and an authored decision become one portable HTML/SVG page with
            no StreamWeaver loaded. Point out the path printed by the demo as proof that
            the artifact is runnable from the installed gem.

            VERIFY silently: check that `$page` exists and contains `<svg`. PRESENT by
            opening `$page` in my default browser; do not use browser automation.

            Say the demo is complete, then wait for my explicit "done". Only after that,
            run `streamweaver university-done 1 --course diagram-intent` and tell me it
            marked this course step done and brought University forward.

            #{ATLAS_GUIDANCE}
          TEXT
          what_you_should_see: [
            'A warm Ruby-styled flowchart with a visible review decision.',
            'An HTML file containing an inline SVG, with no StreamWeaver requirement.',
            'A short path printed from the installed SlimGraphR gem.'
          ]
        },
        {
          number: 2,
          title: 'Choose the picture on purpose',
          payoff: 'Three canned diagrams show that type, style and theme carry meaning before layout begins.',
          why_it_matters: <<~TEXT.strip,
            A flowchart, an architecture diagram and a dependency graph answer different
            questions. Style and theme change presentation without changing the facts.
          TEXT
          prompt: <<~TEXT.strip,
            Housekeeping, backgrounded and waited on by nothing: `( streamweaver canvas-close diagram-intent ) >/dev/null 2>&1 &`.

            Run the packaged comparison before you narrate it:

            #{OPEN_PAGE_HELPER}
            demo="$(streamweaver university-demo semantic --course diagram-intent)"
            printf 'Installed SlimGraphR demo: %s\\n' "$demo"
            page="$(ruby "$demo")"
            printf 'Rendered page: %s\\n' "$page"
            open_page "$page"

            This finished demo is inside the installed SlimGraphR gem. Do not compose a
            replacement and do not inspect a checkout. Narrate the three deliberate
            choices: a flowchart for a decision, architecture for responsibility, and a
            dependency graph for shared requirements. Then point out that `style: :ruby`
            and `theme: :dark` alter the editorial treatment while the modeled relations
            stay explicit.

            VERIFY silently: check that `$page` contains three `<svg` elements. PRESENT
            by opening `$page` in my default browser, not an automation browser.

            Say the demo is complete, then wait for my explicit "done". Only after that,
            run `streamweaver university-done 2 --course diagram-intent` and tell me it
            marked this course step done and brought University forward.

            #{ATLAS_GUIDANCE}
          TEXT
          what_you_should_see: [
            'A flowchart where the review choice is explicit.',
            'An architecture view that distinguishes an external client, service and store.',
            'A dark dependency view that makes a shared requirement visible.'
          ]
        },
        {
          number: 3,
          title: 'Keep the same picture alive and portable',
          payoff: 'The same packaged DSL appears in a live canvas, Canvas Reader and a static HTML export.',
          why_it_matters: <<~TEXT.strip,
            The diagram component works in a live StreamWeaver canvas and remains an
            inline SVG when the same source is reopened or exported.
          TEXT
          prompt: <<~TEXT.strip,
            Housekeeping, backgrounded and waited on by nothing: `( streamweaver canvas-close diagram-intent ) >/dev/null 2>&1 &`.

            Run these commands immediately. Canvas Reader stays in the background; its
            PID and URL are saved under `$TMPDIR` for the later after-done cleanup, while
            the live canvas remains open until that explicit cleanup:

            #{OPEN_PAGE_HELPER}

            #{STEP_THREE_START}

            The DSL file is canned inside the installed SlimGraphR gem. Do not rewrite it
            and do not search for a checkout. Narrate the same content across the live
            canvas, the read-only Canvas Reader and the exported HTML: all three contain
            the actual inline SVG, while the live canvas is the place for active work.

            VERIFY silently: confirm the live canvas, Reader and exported page all contain
            `<svg`. PRESENT the live panel, Reader URL and exported page through the portable
            opener above; do not substitute browser automation. Leave the live canvas open
            while I inspect it. Never close `university`.

            Say the demo is complete, then wait for my explicit "done". Only after that,
            run this cleanup in any shell. It reads the saved state, safely terminates the
            Reader if it is still live, and then closes only the `diagram-intent` live canvas:

            #{STEP_THREE_CLEANUP}

            Then run `streamweaver university-done 3 --course diagram-intent` and tell me
            the course is complete and University is forward.

            #{ATLAS_GUIDANCE}
          TEXT
          what_you_should_see: [
            'A live StreamWeaver canvas with the SlimGraphR diagram component.',
            'The same source rendered by Canvas Reader without an active canvas session.',
            'A self-contained exported HTML page with the SVG inline.'
          ]
        }
      ].map do |step|
        step.transform_values { |value| value.is_a?(Array) ? value.map(&:freeze).freeze : value.freeze }.freeze
      end.freeze

      DEMO_RESOLVER = ->(name) { resolve_demo(name) }.freeze

      COURSE = {
        id: COURSE_ID.freeze,
        title: 'Diagram Intent with SlimGraphR'.freeze,
        blurb: 'Turn a small Ruby description into a clear SVG, carry it into a live canvas and export, then explore every supported form with `streamweaver diagrams`.'.freeze,
        steps: STEPS,
        demo_resolver: DEMO_RESOLVER
      }.freeze

      COURSES = [COURSE].freeze

      def courses
        COURSES
      end

      def self.resolve_demo(name)
        DEMOS[name.to_s.strip.downcase.tr('_ ', '--')]
      end
    end
  end
end
