require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'bounded state machines' do
  def lifecycle(**options)
    SlimGraphR.diagram(:state, title: 'Publish lifecycle', **options) do
      state :draft, 'Draft'
      state :review, 'In review'
      state :published, 'Published', emphasis: true
      initial :draft
      final :published
      transition :draft, :review, on: 'submit', guard: 'complete?', action: 'queue'
      transition :review, :draft, on: 'request changes'
      transition :review, :published, on: 'approve'
    end
  end

  def build(&block) = SlimGraphR.diagram(:state, &block)
  def load_json(value) = SlimGraphR::Document.from_json(JSON.generate(value))

  it 'fits the exact atlas lifecycle while preserving its transition topology and clearances' do
    diagram = SlimGraphR.diagram(:state, title: 'Publish lifecycle', direction: :right) do
      state :draft, 'Draft'
      state :review, 'In review'
      state :published, 'Published', emphasis: true
      initial :draft
      final :published
      transition :draft, :review, on: 'submit', guard: 'complete?'
      transition :review, :draft, on: 'request changes'
      transition :review, :published, on: 'approve'
    end

    scene = diagram.layout
    expect(scene.width).to eq(1360)
    expect(diagram.to_svg(id: 'atlas-state')).to include('viewBox="0 0 1360 ', 'width="1360"', 'min-width:1360px')
    expect(scene.routes.map(&:kind)).to eq(%i[forward feedback forward])
    expect_unambiguous_state_scene(scene)
  end

  # Independent, fine-grained checks of the actual cubic controls (not the router's samples).
  def cubic_segments(route)
    points = (0..320).map do |step|
      t = step / 320.0
      [0, 1].map do |axis|
        (1 - t)**3 * route.start[axis] + 3 * (1 - t)**2 * t * route.control1[axis] +
          3 * (1 - t) * t**2 * route.control2[axis] + t**3 * route.finish[axis]
      end
    end
    points.each_cons(2).to_a
  end

  def segments_cross?(a, b, c, d)
    cross = ->(p, q, r) { (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0]) }
    cross.call(a, b, c) * cross.call(a, b, d) < 0 && cross.call(c, d, a) * cross.call(c, d, b) < 0
  end

  def expect_unambiguous_state_scene(scene)
    curves = scene.routes.to_h { |route| [route, cubic_segments(route)] }
    scene.routes.combination(2) do |a, b|
      crossing = curves[a].any? { |p, q| curves[b].any? { |r, s| segments_cross?(p, q, r, s) } }
      expect(crossing).to be(false), "#{a.transition.label} crosses #{b.transition.label}"
    end
    arrowheads = scene.routes.to_h do |route|
      x, y = route.finish
      dx, dy = x - route.control2[0], y - route.control2[1]
      length = Math.hypot(dx, dy)
      dx, dy = dx / length, dy / length
      [route, [[x, y], [x - 6 * dx - 3 * dy, y - 6 * dy + 3 * dx], [x - 6 * dx + 3 * dy, y - 6 * dy - 3 * dx], [x, y]]]
    end
    scene.routes.each do |owner|
      scene.routes.reject { |other| other.equal?(owner) }.each do |other|
        overlap = arrowheads[owner].each_cons(2).any? { |a, b| curves[other].any? { |c, d| segments_cross?(a, b, c, d) } }
        expect(overlap).to be(false), "#{owner.transition.label} arrowhead overlaps #{other.transition.label}"
      end
    end
    markers = [[scene.entry[:dot], scene.entry[:finish], 6]] + scene.finals.map { |m| [m[:outer], m[:start], 8] }
    markers.each do |center, endpoint, radius|
      curves.each_value do |segments|
        expect(segments.none? { |a, b| segments_cross?(a, b, center, endpoint) }).to be(true)
        expect(segments.flatten(1).map { |x, y| Math.hypot(x - center[0], y - center[1]) }.min).to be > radius + 1
      end
    end
    scene.routes.each do |label_owner|
      left, top, right, bottom = label_owner.label_box.fetch(:rect)
      distance = lambda do |route|
        curves[route].flatten(1).map { |x, y| Math.hypot([left - x, 0, x - right].max, [top - y, 0, y - bottom].max) }.min
      end
      expect(distance.call(label_owner)).to be <= 29
      scene.routes.reject { |other| other.equal?(label_owner) }.each do |other|
        hidden = curves[other].flatten(1).any? { |x, y| x.between?(left, right) && y.between?(top, bottom) }
        expect(hidden).to be(false), "#{label_owner.transition.label} hides #{other.transition.label}"
        expect(distance.call(other)).to be > distance.call(label_owner) + 6
      end
      arrowheads.each_value do |vertices|
        expect(vertices.none? { |x, y| x.between?(left, right) && y.between?(top, bottom) }).to be(true)
      end
    end
  end

  it 'never renders the crossing or label-occlusion regression topologies ambiguously' do
    %i[right down].product([%w[01 02 03 12 13 14 23 34], %w[01 02 03 13 14 23 24 34]]).each do |direction, edges|
      diagram = SlimGraphR.diagram(:state, direction: direction) do
        5.times { |n| state "s#{n}" }
        initial :s0
        final :s4
        edges.each { |edge| transition "s#{edge[0]}", "s#{edge[1]}", on: edge }
      end
      begin
        expect_unambiguous_state_scene(diagram.layout)
      rescue SlimGraphR::LayoutError => error
        expect(error.message).to match(/(route|separate|label).*split the state machine/i)
      end
    end
  end

  it 'keeps self-loops distinct from incoming and feedback curves in both directions' do
    %i[right down].each do |direction|
      diagram = SlimGraphR.diagram(:state, direction: direction) do
        state :draft
        state :review
        state :done
        initial :draft
        final :done
        transition :draft, :review, on: 'submit', guard: 'complete?', action: 'queue'
        transition :review, :draft, on: 'request changes'
        transition :review, :review, on: 'recheck', action: 'record audit'
        transition :review, :done, on: 'approve'
      end
      expect_unambiguous_state_scene(diagram.layout)
    end
  end

  it 'builds dedicated immutable state and transition records with readable labels' do
    diagram = lifecycle
    expect(diagram.states.map(&:id)).to eq(%w[draft review published])
    expect(diagram.initial_state).to eq('draft')
    expect(diagram.final_states).to eq(%w[published])
    expect(diagram.transitions.map(&:label)).to eq(['submit [complete?] / queue', 'request changes', 'approve'])
    expect(diagram.states).to be_frozen
    expect(diagram.transitions).to be_frozen
    expect(diagram.states).to all(be_frozen)
    expect(diagram.transitions).to all(be_frozen)
  end

  it 'keeps the state DSL separate from generic graph semantics' do
    %i[node edge flow group event].each do |operation|
      expect do
        build do
          state :a
          state :b
          initial :a
          final :b
          transition :a, :b, on: 'go'
          public_send(operation, :wrong, :shape)
        end
      end.to raise_error(SlimGraphR::Error, /state machine/i), operation.to_s
    end
    expect { build { state :a, detail: ' ' } }.to raise_error(SlimGraphR::Error, /detail.*blank/i)
  end

  it 'requires named transitions, one initial, one or two finals, and known references' do
    expect { build { state :a; state :b; final :b; transition :a, :b, on: 'go' } }.to raise_error(SlimGraphR::Error, /exactly one initial/i)
    expect { build { state :a; state :b; initial :a; initial :b; final :b; transition :a, :b, on: 'go' } }.to raise_error(SlimGraphR::Error, /exactly one initial/i)
    expect { build { state :a; state :b; initial :a; final :b } }.to raise_error(SlimGraphR::Error, /at least one transition/i)
    expect { build { state :a; state :b; initial :a; final :b; transition :a, :b, on: ' ' } }.to raise_error(SlimGraphR::Error, /event.*blank/i)
    expect { build { state :a; state :b; initial :a; final :b; transition :a, :b, on: 'go', guard: ' ' } }.to raise_error(SlimGraphR::Error, /guard.*blank/i)
    expect { build { state :a; state :b; initial :a; final :b; transition :a, :b, on: 'go', action: ' ' } }.to raise_error(SlimGraphR::Error, /action.*blank/i)
    expect { build { state :a; state :b; initial :missing; final :b; transition :a, :b, on: 'go' } }.to raise_error(SlimGraphR::Error, /Unknown initial state: missing/)
    expect { build { state :a; state :b; initial :a; final :missing; transition :a, :b, on: 'go' } }.to raise_error(SlimGraphR::Error, /Unknown final state: missing/)
  end

  it 'rejects blank Ruby state IDs and marker or transition references' do
    expect do
      build do
        state ' ', 'Named despite blank ID'
        state :b
        initial ' '
        final :b
        transition ' ', :b, on: 'go'
      end
    end.to raise_error(SlimGraphR::Error, /State IDs must be nonblank and unique/)
    expect { build { state :a; state :b; initial ' '; final :b; transition :a, :b, on: 'go' } }.to raise_error(SlimGraphR::Error, /Initial state must not be blank/)
    expect { build { state :a; state :b; initial :a; final ' '; transition :a, :b, on: 'go' } }.to raise_error(SlimGraphR::Error, /Final state must not be blank/)
    expect { build { state :a; state :b; initial :a; final :b; transition ' ', :b, on: 'go' } }.to raise_error(SlimGraphR::Error, /Transition source must not be blank/)
    expect { build { state :a; state :b; initial :a; final :b; transition :a, ' ', on: 'go' } }.to raise_error(SlimGraphR::Error, /Transition target must not be blank/)
  end

  it 'allows incoming recovery to the initial state and rejects outgoing terminal transitions' do
    expect(lifecycle.transitions).to include(have_attributes(from: 'review', to: 'draft'))
    expect do
      build do
        state :a
        state :done
        initial :a
        final :done
        transition :a, :done, on: 'finish'
        transition :done, :a, on: 'reopen'
      end
    end.to raise_error(SlimGraphR::Error, /Final state done cannot have outgoing transitions/)
  end

  it 'validates lifecycle reachability in both directions' do
    expect do
      build do
        state :a
        state :done
        state :lost
        initial :a
        final :done
        transition :a, :done, on: 'finish'
        transition :lost, :done, on: 'recover'
      end
    end.to raise_error(SlimGraphR::Error, /not reachable from initial: lost/)
    expect do
      build do
        state :a
        state :stuck
        state :done
        initial :a
        final :done
        transition :a, :stuck, on: 'stall'
        transition :a, :done, on: 'finish'
        transition :stuck, :stuck, on: 'wait'
      end
    end.to raise_error(SlimGraphR::Error, /cannot reach a final state: stuck/)
  end

  it 'enforces the explicit size, degree, pair, loop, and emphasis budgets' do
    expect { build { state :a; initial :a; final :a; transition :a, :a, on: 'stay' } }.to raise_error(SlimGraphR::Error, /two to twelve states/i)
    expect do
      build do
        state :a
        state :b
        initial :a
        final :b
        transition :a, :b, on: 'one'
        transition :a, :b, on: 'two'
      end
    end.to raise_error(SlimGraphR::Error, /one transition per ordered pair/i)
    expect do
      build do
        state :a
        state :b
        state :c
        initial :a
        final :c
        transition :a, :a, on: 'retry'
        transition :a, :a, on: 'retry again'
        transition :a, :b, on: 'go'
        transition :b, :c, on: 'finish'
      end
    end.to raise_error(SlimGraphR::Error, /one transition per ordered pair|one self-loop/i)
    expect do
      build do
        state :a, emphasis: true
        state :b, emphasis: true
        state :c, emphasis: true
        initial :a
        final :c
        transition :a, :b, on: 'go'
        transition :b, :c, on: 'finish'
      end
    end.to raise_error(SlimGraphR::Error, /at most two emphasized/i)
  end

  it 'accepts one simple 2–4 state cycle and rejects multiple, overlapping, or larger cycles' do
    expect(lifecycle).to be_a(SlimGraphR::Diagram)
    expect do
      build do
        %i[a b c d e done].each { |id| state id }
        initial :a
        final :done
        transition :a, :b, on: '1'
        transition :b, :c, on: '2'
        transition :c, :d, on: '3'
        transition :d, :e, on: '4'
        transition :e, :a, on: '5'
        transition :e, :done, on: 'finish'
      end
    end.to raise_error(SlimGraphR::Error, /cycle.*two to four states/i)
    expect do
      build do
        %i[a b c d done].each { |id| state id }
        initial :a
        final :done
        transition :a, :b, on: 'ab'
        transition :b, :a, on: 'ba'
        transition :a, :c, on: 'ac'
        transition :c, :a, on: 'ca'
        transition :a, :d, on: 'ad'
        transition :d, :done, on: 'finish'
      end
    end.to raise_error(SlimGraphR::Error, /one simple directed cycle/i)
  end

  it 'loads strict JSON with byte-identical Ruby semantics and rejects cross-type or null fields' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = eval(File.read(File.join(root, 'state_machine.rb')), binding, File.join(root, 'state_machine.rb'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'state_machine.json')))
    expect(json.to_svg(id: 'state-parity')).to eq(ruby.to_svg(id: 'state-parity'))

    base = {
      type: 'state', states: [{ id: 'a' }, { id: 'b' }], initial: 'a', finals: ['b'],
      transitions: [{ from: 'a', to: 'b', on: 'go' }]
    }
    %i[nodes edges groups events steps escalations approvals].each do |field|
      expect { load_json(base.merge(field => [])) }.to raise_error(SlimGraphR::Error, /state.*does not accept.*#{field}/i), field.to_s
    end
    expect { load_json(base.merge(transitions: [{ from: 'a', to: 'b', on: nil }])) }.to raise_error(SlimGraphR::Error, /on must be a string/)
    detailed = load_json(base.merge(states: [{ id: 'a', detail: 'author supplied detail' }, { id: 'b' }]))
    expect(detailed.states.first.detail).to eq('author supplied detail')
    expect(detailed.to_svg(id: 'state-detail')).to include('data-sgr-state-detail="a"', 'author supplied detail')
    expect { load_json(base.merge(states: [{ id: 'a', detail: nil }, { id: 'b' }])) }.to raise_error(SlimGraphR::Error, /detail must be a string/)
    expect { load_json(base.merge(finals: nil)) }.to raise_error(SlimGraphR::Error, /finals must be an array/)
    expect { load_json(base.merge(initial: ' ')) }.to raise_error(SlimGraphR::Error, /initial must not be empty/)
    expect { load_json(type: 'architecture', states: []) }.to raise_error(SlimGraphR::Error, /Only a state machine accepts states/)
  end

  it 'renders rounded states, exact entry/final markers, curved paths, mono labels, and semantics in the description' do
    svg = lifecycle.to_svg(id: 'state-visual')
    expect(svg).to include('data-sgr-state="draft"', 'rx="8"', 'data-sgr-state-entry="draft"', 'r="6"')
    expect(svg).to include('data-sgr-state-final="published"', 'r="8"', 'r="5"')
    expect(svg.scan('data-sgr-state-transition=').size).to eq(3)
    expect(svg).to match(/data-sgr-state-transition="draft-review"[^>]+d="M [^"]+ C [^"]+"/)
    expect(svg).to include('class="sgr-state-label"', "font-family:'Geist Mono',ui-monospace,monospace")
    expect(svg).to include('Initial: Draft', 'Final: Published', 'submit [complete?] / queue')
  end

  it 'lays out right and down diagrams with measured Unicode labels and unobstructed sampled curves' do
    %i[right down].each do |direction|
      diagram = SlimGraphR.diagram(:state, title: '配信 lifecycle', direction: direction) do
        state :draft, '下書き — a deliberately long lifecycle state label'
        state :review, 'Review ✓'
        state :done, '公開済み', emphasis: true
        initial :draft
        final :done
        transition :draft, :review, on: '提出する', guard: '完全?', action: 'queue_job'
        transition :review, :review, on: '再確認', action: '監査する'
        transition :review, :done, on: '承認する'
      end
      scene = diagram.layout
      expect(scene.width).to be > 0
      expect(scene.height).to be > 0
      expect(scene.routes).to all(satisfy { |route| route.samples.size >= 17 })
      scene.routes.each do |route|
        route.samples[1...-1].each do |point|
          expect(point[0]).to be_between(0, scene.width)
          expect(point[1]).to be_between(0, scene.height)
        end
        next unless route.label_box
        expect(scene.boxes.none? { |box| SlimGraphR::Layout::Geometry.overlaps?(route.label_box[:rect], box.rect(8)) }).to be(true)
      end
      expect { REXML::Document.new(diagram.to_svg) }.not_to raise_error
    end
  end

  it 'uses an outside feedback lane for a multi-state cycle and a curved loop above its state' do
    diagram = SlimGraphR.diagram(:state, direction: :right) do
      state :draft
      state :review
      state :done
      initial :draft
      final :done
      transition :draft, :review, on: 'submit'
      transition :review, :draft, on: 'changes'
      transition :review, :review, on: 'recheck'
      transition :review, :done, on: 'approve'
    end
    scene = diagram.layout
    feedback = scene.routes.find { |route| route.kind == :feedback }
    loop_route = scene.routes.find { |route| route.kind == :self_loop }
    expect(feedback.samples.map(&:last).min).to be < scene.boxes.map(&:y).min
    review = scene.boxes.find { |box| box.node.id == 'review' }
    expect(loop_route.samples.map(&:last).min).to be < review.y
    expect(feedback.label_box[:rect][3]).to be <= review.y
    expect(loop_route.label_box[:rect][3]).to be <= review.y
  end

  it 'renders every style across light, dark, and auto without changing geometry' do
    baseline = lifecycle.layout
    SlimGraphR::Style::PROFILES.each_key do |style|
      %i[light dark auto].each do |theme|
        diagram = lifecycle(style: style, theme: theme)
        scene = diagram.layout
        expect(scene.boxes.map { |box| [box.x, box.y, box.width, box.height] }).to eq(baseline.boxes.map { |box| [box.x, box.y, box.width, box.height] })
        expect(diagram.to_svg).to include(%(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}"))
      end
    end
  end
end
