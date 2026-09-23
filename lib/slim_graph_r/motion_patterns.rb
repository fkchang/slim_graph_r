# frozen_string_literal: true

module SlimGraphR
  module Motion
    class PatternDiagram
      TYPES = %i[fan_in_queue paired_policy_trace secure_paved_road].freeze
      attr_reader :type, :title, :style, :theme

      def initialize(type, title: nil, style: :ruby, theme: :light)
        @type = type.to_sym
        raise Error, "Unknown motion pattern: #{type}" unless TYPES.include?(@type)
        @title = Text.clean(title || default_title)
        @style = Style.fetch(style).name
        @theme = theme.to_sym
        raise Error, 'Theme must be :light, :dark, or :auto' unless %i[light dark auto].include?(@theme)
        freeze
      end

      def style_profile = Style.fetch(style)
      def with(style: @style, theme: @theme, **) = self.class.new(type, title: title, style: style, theme: theme)
      def presentation = Presentation.new(self, pattern_storyboard)
      def to_svg(id: nil) = to_motion_svg(pattern_storyboard, id: id, static: true)
      def to_html = MotionPlayer.static_document(presentation)
      def to_motion_svg(storyboard, id: nil, static: false) = PatternSVG.new(self, storyboard, id: id, static: static).render

      private

      def default_title
        { fan_in_queue: 'Fan-in queue under pressure', paired_policy_trace: 'Policy trace: first divergence',
          secure_paved_road: 'Secure paved road' }.fetch(type)
      end

      def pattern_storyboard
        case type
        when :fan_in_queue
          Storyboard.build do
            reveal 1, :web, :mobile, :depth_two, 'Steady traffic occupies two of five queue slots'
            reveal 2, :payments, :erp, :depth_five, 'Burst traffic fills the queue', replaces: :depth_two
            reveal 3, :overflow, 'Overflow sheds nineteen requests per second to the 429 sink'
            reveal 4, :worker, 'The constrained worker serves eight requests per second'
            reveal 5, :downstream, 'The system reaches controlled equilibrium'
          end
        when :paired_policy_trace
          Storyboard.build do
            reveal 1, :rule_identity, 'Identity bound passes for both traces'
            reveal 2, :rule_audience, 'Internal audience passes for both traces'
            reveal 3, :rule_data_class, 'Data class is the first divergence'
            reveal 4, :rule_approval, 'Human approval is skipped or not reached'
            reveal 5, :rule_deploy, 'Deploy gate finishes with permit and deny outcomes'
          end
        when :secure_paved_road
          Storyboard.build do
            reveal 1, :commit, 'A signed commit enters the paved road'
            reveal 2, :build, 'CI builds the artifact and records provenance'
            reveal 3, :approved, 'Policy verification admits the approved deployment route'
            reveal 4, :blocked, 'The unauthorized route stops at the trust boundary'
            reveal 5, :audit, 'The immutable audit records allowed and blocked activity'
          end
        end
      end
    end

    class PatternSVG
      def initialize(diagram, storyboard, id: nil, static: false)
        @diagram, @storyboard, @static = diagram, storyboard, static
        @id = id || "sgr-#{SecureRandom.hex(6)}"
        unless @id.match?(/\A[a-zA-Z][a-zA-Z0-9_-]*\z/)
          raise Error, 'SVG ID must start with a letter and contain only letters, digits, hyphens, underscores'
        end
        @out, @rendered = [], {}
      end

      def render
        send("draw_#{@diagram.type}")
        @storyboard.validate_rendered!(@rendered.keys)
        @out.join
      end

      private

      def open_svg(width, height, description)
        light_vars = @diagram.style_profile.light.map { |key, value| "--sgr-#{key}:#{value}" }.join(';')
        dark_vars = @diagram.style_profile.dark.map { |key, value| "--sgr-#{key}:#{value}" }.join(';')
        vars = @diagram.theme == :dark ? dark_vars : light_vars
        auto_theme = if @diagram.theme == :auto
          "@media(prefers-color-scheme:dark){##{@id}{#{dark_vars}}} [data-theme=dark] ##{@id},[data-sw-theme=dark] ##{@id},.dark ##{@id}{#{dark_vars}} [data-theme=light] ##{@id},html:not(.dark)[data-sw-theme=light] ##{@id}{#{light_vars}}"
        else
          ''
        end
        @out << %(<svg xmlns="http://www.w3.org/2000/svg" id="#{@id}" class="sgr-diagram sgr-motion-pattern" data-sgr-motion-pattern="#{@diagram.type}" data-sgr-theme="#{@diagram.theme}" data-sgr-style="#{@diagram.style}" role="img" aria-labelledby="#{@id}-title #{@id}-desc" viewBox="0 0 #{width} #{height}" width="#{width}" height="#{height}" style="display:block;margin:0 auto;width:100%;height:auto;min-width:760px;max-width:#{width}px;#{vars}">)
        @out << %(<title id="#{@id}-title">#{esc(@diagram.title)}</title><desc id="#{@id}-desc">#{esc(description)}</desc>)
        @out << <<~SVG
          <style>
            ##{@id}{font-family:Geist,'Helvetica Neue',Arial,sans-serif;background:var(--sgr-paper)}
            #{auto_theme}
            ##{@id} text{fill:var(--sgr-ink);font-size:16px} ##{@id} .title{font-family:#{@diagram.style_profile.heading_family};font-size:32px}
            ##{@id} .mono{font-family:'Geist Mono',ui-monospace,monospace;font-size:13px} ##{@id} .muted{fill:var(--sgr-muted)}
            ##{@id} .small{font-size:12px} ##{@id} .strong{font-weight:700} ##{@id} .accent{fill:var(--sgr-accent)}
          </style>
          <rect width="#{width}" height="#{height}" fill="var(--sgr-paper)"/>
          <text class="title" x="48" y="52">#{esc(@diagram.title)}</text>
          <line x1="48" y1="78" x2="#{width - 48}" y2="78" stroke="var(--sgr-rule)"/>
        SVG
      end

      def close_svg = @out << '</svg>'
      def esc(value) = CGI.escapeHTML(value.to_s)
      def line(x1, y1, x2, y2, color: 'var(--sgr-muted)', width: 2, dash: nil)
        @out << %(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" stroke="#{color}" stroke-width="#{width}"#{dash ? " stroke-dasharray=\"#{dash}\"" : ''}/>)
      end
      def card(x, y, width, height, title, detail = nil, accent: false, dashed: false)
        @out << %(<rect x="#{x}" y="#{y}" width="#{width}" height="#{height}" rx="8" fill="#{accent ? 'var(--sgr-tint)' : 'var(--sgr-paper)'}" stroke="#{accent ? 'var(--sgr-accent)' : 'var(--sgr-ink)'}"#{dashed ? ' stroke-dasharray="5 4"' : ''}/>)
        @out << %(<text class="strong" x="#{x + 14}" y="#{y + 28}">#{esc(title)}</text>)
        @out << %(<text class="mono muted" x="#{x + 14}" y="#{y + 50}">#{esc(detail)}</text>) if detail
      end

      def item(id)
        target = Target.node(id)
        step = @storyboard.step_for(target.key)
        @rendered[target.key] = true
        return if @static && @storyboard.replaced_at(target.key)
        return yield if @static
        attributes = [
          'data-motion-item="true"', %(data-motion-key="#{esc(target.key)}"), %(data-step="#{step.number}"),
          %(aria-label="#{esc("Step #{step.number}: #{step.label}")}")
        ]
        until_step = @storyboard.replaced_at(target.key)
        attributes << %(data-motion-until="#{until_step}") if until_step
        attributes << %(data-motion-replaces="#{esc(step.replaces.join(' '))}") unless step.replaces.empty?
        @out << "<g #{attributes.join(' ')}>"; yield; @out << '</g>'
      end

      def draw_fan_in_queue
        open_svg(1160, 620, 'Four producers converge on a five-slot queue. A burst fills it, overflow is shed, and an eight request-per-second worker reaches controlled equilibrium.')
        [['WEB APP', 4, 116], ['MOBILE API', 3, 194]].each_with_index do |(name, rate, y), index|
          item(index.zero? ? :web : :mobile) { card(52, y, 190, 62, name, "#{rate} req/s steady") }
        end
        [['PAYMENTS', 8, 300], ['ERP', 12, 378]].each_with_index do |(name, rate, y), index|
          item(index.zero? ? :payments : :erp) { card(52, y, 190, 62, name, "#{rate} req/s burst", accent: true) }
        end
        @out << '<rect x="390" y="174" width="360" height="156" rx="12" fill="none" stroke="var(--sgr-ink)" stroke-width="2"/>'
        @out << '<text class="strong" x="408" y="160">FIFO QUEUE · CAPACITY 5</text>'
        5.times { |i| @out << %(<rect x="#{410 + i * 64}" y="220" width="50" height="58" rx="5" fill="var(--sgr-secondary)" stroke="var(--sgr-rule)"/>) }
        item(:depth_two) { @out << '<rect x="492" y="290" width="150" height="26" rx="4" fill="var(--sgr-secondary)"/><text class="mono" x="511" y="308">DEPTH 2 / 5</text>' }
        item(:depth_five) { @out << '<rect x="492" y="290" width="150" height="26" rx="4" fill="var(--sgr-tint)" stroke="var(--sgr-accent)"/><text class="mono accent" x="511" y="308">DEPTH 5 / 5</text>' }
        item(:overflow) do
          line(570, 330, 570, 418, color: 'var(--sgr-accent)', width: 2)
          card(464, 424, 212, 66, '429 RATE LIMITER', '19 req/s shed', accent: true)
        end
        item(:worker) do
          line(750, 252, 842, 252, width: 2)
          card(842, 210, 240, 84, 'CONSTRAINED WORKER', '8 req/s max', accent: true)
        end
        item(:downstream) do
          line(962, 294, 962, 392, color: 'var(--sgr-link)', width: 2)
          card(842, 398, 240, 76, 'DOWNSTREAM', '200 OK · controlled')
          @out << '<text class="mono muted" x="390" y="552">7 steady + 20 burst → 8 served + 19 shed</text>'
        end
        [[242,147,390,215],[242,225,390,235],[242,331,390,270],[242,409,390,290]].each { |a| line(*a, width: 1.5) }
        close_svg
      end

      def draw_paired_policy_trace
        open_svg(1200, 660, 'Two requests traverse the same five policy rules. They first diverge at data class and finish permitted and denied.')
        @out << '<text class="mono strong" x="510" y="112">TRACE A · INTERNAL RELEASE</text><text class="mono strong" x="820" y="112">TRACE B · EXTERNAL RELEASE</text>'
        rows = [
          [:rule_identity, '1', 'IDENTITY BOUND', 'PASS', 'PASS'],
          [:rule_audience, '2', 'INTERNAL AUDIENCE', 'PASS', 'PASS'],
          [:rule_data_class, '3', 'DATA CLASS', 'PASS', 'FAIL'],
          [:rule_approval, '4', 'HUMAN APPROVAL', 'SKIPPED', 'NOT REACHED'],
          [:rule_deploy, '5', 'DEPLOY GATE', 'PASS · PERMIT', 'NOT REACHED · DENY']
        ]
        rows.each_with_index do |(id, number, rule, left, right), index|
          y = 138 + index * 82
          item(id) do
            accent = index == 2
            @out << %(<rect x="70" y="#{y}" width="1060" height="66" rx="6" fill="#{accent ? 'var(--sgr-tint)' : 'var(--sgr-paper)'}" stroke="#{accent ? 'var(--sgr-accent)' : 'var(--sgr-rule)'}"/>)
            @out << %(<text class="mono #{accent ? 'accent' : 'muted'}" x="94" y="#{y + 39}">#{number}</text><text class="strong" x="138" y="#{y + 39}">#{rule}</text>)
            @out << %(<text class="mono strong" x="570" y="#{y + 39}" text-anchor="middle">#{left}</text><text class="mono #{right.include?('FAIL') || right.include?('DENY') ? 'accent' : 'strong'}" x="890" y="#{y + 39}" text-anchor="middle">#{right}</text>)
            @out << '<text class="mono accent" data-sgr-first-divergence="true" x="72" y="594">FIRST DIVERGENCE: RULE 3 · DATA CLASS</text>' if index == 2
          end
        end
        @out << '<line x1="402" y1="126" x2="402" y2="548" stroke="var(--sgr-rule)"/><line x1="730" y1="126" x2="730" y2="548" stroke="var(--sgr-rule)"/>'
        close_svg
      end

      def draw_secure_paved_road
        open_svg(1160, 620, 'An approved signed artifact crosses a policy gate into an isolated runtime. An unauthorized route stops at the firewall. Both outcomes reach immutable audit.')
        [['DEVELOPMENT', 44, 112, 246], ['DELIVERY', 322, 112, 432], ['PRODUCTION', 786, 112, 330]].each do |label, x, y, width|
          @out << %(<rect x="#{x}" y="#{y}" width="#{width}" height="374" rx="12" fill="none" stroke="var(--sgr-rule)" stroke-dasharray="6 5"/><text class="mono muted strong" x="#{x + 16}" y="#{y + 26}">#{label}</text>)
        end
        item(:commit) do
          card(70, 190, 194, 76, 'DEVELOPER', 'signed commit')
          line(264, 228, 358, 228, width: 2)
        end
        item(:build) do
          card(358, 178, 180, 100, 'CI BUILD', 'artifact + provenance', accent: true)
          line(538, 228, 588, 228, width: 2)
        end
        item(:approved) do
          card(588, 178, 166, 100, 'POLICY GATE', 'OPA · approved', accent: true)
          line(754, 228, 814, 228, color: 'var(--sgr-link)', width: 2)
          card(814, 178, 132, 100, 'GATEWAY', 'production API')
          line(946, 228, 970, 228, color: 'var(--sgr-link)', width: 2)
          card(970, 178, 120, 100, 'CORE DB', 'isolated')
        end
        item(:blocked) do
          card(70, 340, 194, 76, 'ATTACKER', 'unauthorized bypass', dashed: true)
          line(264, 378, 724, 378, color: 'var(--sgr-accent)', width: 2, dash: '7 5')
          @out << '<rect x="724" y="330" width="30" height="96" fill="var(--sgr-tint)" stroke="var(--sgr-accent)"/><text class="mono accent" data-sgr-blocked-label="true" x="520" y="446">BLOCKED AT FIREWALL</text>'
        end
        item(:audit) do
          @out << '<g data-sgr-audit-card="true">'
          card(814, 378, 276, 78, 'IMMUTABLE SIEM AUDIT', 'approved + blocked activity')
          @out << '</g>'
          line(672, 278, 900, 378, color: 'var(--sgr-link)', width: 1.5)
          line(754, 378, 814, 417, color: 'var(--sgr-accent)', width: 1.5, dash: '5 4')
        end
        close_svg
      end
    end
  end
end
