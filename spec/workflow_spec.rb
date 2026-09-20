# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'workflow diagrams' do
  def svg_attributes(tag)
    tag.scan(/([\w:-]+)="([^"]*)"/).to_h
  end

  def svg_tag(svg, element, attribute, value)
    svg.scan(/<#{element}\b[^>]*>/).find { |tag| svg_attributes(tag)[attribute] == value }
  end

  def swimlane(**options)
    SlimGraphR.diagram(:swimlane, title: 'Survey handoff', **options) do
      lane :research, 'Research'
      lane :it, 'IT'
      stage :design, 'Design'
      stage :build, 'Build'
      stage :test, 'Test'
      activity :draft, 'Draft survey', lane: :research, stage: :design
      activity :build_app, 'Build app', lane: :it, stage: :build
      activity :pilot, 'Pilot test', lane: :research, stage: :test
      handoff :draft, :build_app, focal: true
      handoff :build_app, :pilot
    end
  end

  def process(**options)
    SlimGraphR.diagram(:process, title: 'Quarterly survey', **options) do
      lane :research, 'Research', key: 'RDE'
      lane :it, 'IT', key: 'IT'
      lane :field, 'Field services', key: 'FLD'
      stage :design, 'Design'
      stage :build, 'Build'
      stage :test, 'Test', focal: true
      operation :draft, 'Draft survey', lane: :research, stage: :design, tool: 'Excel', output: 'FL'
      operation :build_app, 'Build app', lane: :it, stage: :build, tool: 'CSPro', detail: 'form + validation', input: 'FL', output: 'TB'
      operation :pilot, 'Pilot test', lane: :field, stage: :test, tool: 'Tablet', input: 'TB', focal: true
      handoff :draft, :build_app
      handoff :build_app, :pilot
      trigger :pilot, :build_app, 'RETEST'
    end
  end

  it 'models dedicated actor lanes, numbered stages, cards and explicit handoffs' do
    graph = swimlane
    expect(graph.direction).to eq(:right)
    expect(graph.workflow_lanes.map { |item| [item.id, item.label, item.key] }).to eq([
      ['research', 'Research', nil], ['it', 'IT', nil]
    ])
    expect(graph.workflow_stages.map { |item| [item.id, item.label, item.number, item.focal] }).to eq([
      ['design', 'Design', 1, false], ['build', 'Build', 2, false], ['test', 'Test', 3, false]
    ])
    expect(graph.activities.map { |item| [item.id, item.label, item.lane, item.stage] }).to include(
      ['draft', 'Draft survey', 'research', 'design']
    )
    expect(graph.workflow_handoffs.count(&:focal)).to eq(1)
    expect(graph.operations).to be_empty
  end

  it 'models tools, details, payload codes, focal slots and the named return trigger' do
    graph = process
    expect(graph.workflow_lanes.map(&:key)).to eq(%w[RDE IT FLD])
    expect(graph.workflow_stages.count(&:focal)).to eq(1)
    expect(graph.operations.count(&:focal)).to eq(1)
    expect(graph.operations[1].then { |item| [item.tool, item.detail, item.input, item.output] }).to eq(['CSPro', 'form + validation', 'FL', 'TB'])
    expect(graph.workflow_trigger.then { |item| [item.from, item.to, item.label] }).to eq(%w[pilot build_app RETEST])
    expect(graph.activities).to be_empty
  end

  it 'uses humanized defaults and deep-freezes dedicated state' do
    graph = SlimGraphR.diagram(:swimlane) do
      lane :customer_success
      stage :intake
      activity :review_request, lane: :customer_success, stage: :intake
    end
    expect(graph.workflow_lanes.first.label).to eq('Customer Success')
    expect(graph.workflow_stages.first.label).to eq('Intake')
    expect(graph.activities.first.label).to eq('Review Request')
    [graph.workflow_lanes, graph.workflow_stages, graph.activities, graph.workflow_handoffs].each { |items| expect(items).to be_frozen }
    (graph.workflow_lanes + graph.workflow_stages + graph.activities).each { |item| expect(item).to be_frozen }
    expect { graph.activities.first.label << '!' }.to raise_error(FrozenError)
  end

  it 'enforces lane, stage, card, and handoff budgets plus one card per cell' do
    expect do
      SlimGraphR.diagram(:swimlane) { 7.times { |i| lane "l#{i}" }; stage :s; activity :a, lane: :l0, stage: :s }
    end.to raise_error(SlimGraphR::Error, /one to six lanes/i)
    expect do
      SlimGraphR.diagram(:swimlane) { lane :l; 13.times { |i| stage "s#{i}" }; activity :a, lane: :l, stage: :s0 }
    end.to raise_error(SlimGraphR::Error, /one to twelve stages/i)
    expect do
      SlimGraphR.diagram(:swimlane) do
        lane :l; stage :s; activity :a, lane: :l, stage: :s; activity :b, lane: :l, stage: :s
      end
    end.to raise_error(SlimGraphR::Error, /one card per lane.*stage cell/i)
    expect do
      SlimGraphR.diagram(:swimlane) { lane :l; stage :s }
    end.to raise_error(SlimGraphR::Error, /at least one activity/i)
  end

  it 'keeps IDs unique across the model and validates explicit references' do
    expect do
      SlimGraphR.diagram(:swimlane) { lane :same; stage :same; activity :a, lane: :same, stage: :same }
    end.to raise_error(SlimGraphR::Error, /unique across lanes, stages, and activities/i)
    expect do
      SlimGraphR.diagram(:swimlane) { lane :l; stage :s; activity :a, lane: :missing, stage: :s }
    end.to raise_error(SlimGraphR::Error, /unknown workflow lane/i)
    expect do
      SlimGraphR.diagram(:swimlane) { lane :l; stage :s; activity :a, lane: :l, stage: :s; handoff :a, :missing }
    end.to raise_error(SlimGraphR::Error, /unknown workflow card/i)
  end

  it 'allows one optional swimlane focal handoff without requiring a focal card or stage' do
    expect(swimlane.workflow_stages.none?(&:focal)).to be(true)
    expect(swimlane.activities).to all(satisfy { |item| !item.focal })
    expect do
      SlimGraphR.diagram(:swimlane) do
        lane :a; lane :b; stage :one; stage :two; stage :three
        activity :x, lane: :a, stage: :one; activity :y, lane: :b, stage: :two; activity :z, lane: :a, stage: :three
        handoff :x, :y, focal: true; handoff :y, :z, focal: true
      end
    end.to raise_error(SlimGraphR::Error, /at most one focal handoff/i)
  end

  it 'requires exactly one process focal stage and operation and keeps trigger style independent' do
    expect do
      SlimGraphR.diagram(:process) do
        lane :l, key: 'L'; stage :s; operation :a, lane: :l, stage: :s, tool: 'T'
      end
    end.to raise_error(SlimGraphR::Error, /exactly one focal stage/i)
    expect(process.workflow_handoffs.first.focal).to be(false)
    styles = process.layout.routes.to_h { |route| [[route.edge.from, route.edge.to], route.style] }
    expect(styles[%w[build_app pilot]]).to eq(:accent)
    expect(styles[%w[pilot build_app]]).to eq(:trigger)
  end

  it 'validates process lane keys, required tools, payload codes, and boundary payloads' do
    expect do
      SlimGraphR.diagram(:process) do
        lane :a, key: 'TOOLONG'; stage :one, focal: true; operation :x, lane: :a, stage: :one, tool: 'T', focal: true
      end
    end.to raise_error(SlimGraphR::Error, /key.*one to three/i)
    expect do
      SlimGraphR.diagram(:process) do
        lane :a, key: 'A'; lane :b, key: 'A'; stage :one, focal: true; operation :x, lane: :a, stage: :one, tool: 'T', focal: true
      end
    end.to raise_error(SlimGraphR::Error, /lane keys must be unique/i)
    expect do
      SlimGraphR.diagram(:process) do
        lane :a, key: 'A'; stage :one, focal: true; operation :x, lane: :a, stage: :one, tool: '', focal: true
      end
    end.to raise_error(SlimGraphR::Error, /tool must not be blank/i)
    expect do
      SlimGraphR.diagram(:process) do
        lane :a, key: 'A'; stage :one, focal: true; operation :x, lane: :a, stage: :one, tool: 'T', input: 'DB', focal: true
      end
    end.to raise_error(SlimGraphR::Error, /first-stage input/i)
    expect do
      SlimGraphR.diagram(:process) do
        lane :a, key: 'A'; stage :one, focal: true; operation :x, lane: :a, stage: :one, tool: 'T', output: 'XX', focal: true
      end
    end.to raise_error(SlimGraphR::Error, /payload.*LS, DB, TB, FL, WB/i)
  end

  it 'accepts omitted and explicit null payloads without inferring conversions' do
    graph = SlimGraphR.diagram(:process) do
      lane :a, key: 'A'; stage :one; stage :two, focal: true
      operation :x, lane: :a, stage: :one, tool: 'T', output: 'DB'
      operation :y, lane: :a, stage: :two, tool: 'T', input: nil, focal: true
      handoff :x, :y
    end
    expect(graph.operations.map { |item| [item.input, item.output] }).to eq([[nil, 'DB'], [nil, nil]])
  end

  it 'permits only forward ordinary handoffs and one labelled backward trigger' do
    expect do
      SlimGraphR.diagram(:swimlane) do
        lane :l; stage :one; stage :two; activity :a, lane: :l, stage: :one; activity :b, lane: :l, stage: :two; handoff :b, :a
      end
    end.to raise_error(SlimGraphR::Error, /handoffs must advance/i)
    expect do
      SlimGraphR.diagram(:process) do
        lane :l, key: 'L'; stage :one; stage :two, focal: true
        operation :a, lane: :l, stage: :one, tool: 'T'; operation :b, lane: :l, stage: :two, tool: 'T', focal: true
        trigger :b, :a, ''
      end
    end.to raise_error(SlimGraphR::Error, /trigger label must not be blank/i)
  end

  it 'uses deterministic fixed cells, exact numbering, one-bend forward routes, and a reserved return band' do
    scene = process.layout
    expect(scene.width).to eq(672)
    expect(scene.workflow_header_height).to eq(36)
    expect(scene.workflow_lane_height).to eq(80)
    expect(scene.boxes.map { |box| [box.x, box.y, box.width, box.height] }).to eq([
      [148, 44, 156, 64], [316, 124, 156, 64], [484, 204, 156, 64]
    ])
    expect(scene.workflow_stages.map { |item| item[:number] }).to eq([1, 2, 3])
    ordinary = scene.routes.reject { |route| route.style == :trigger }
    expect(ordinary).to all(satisfy { |route| route.points.size <= 4 })
    expect(ordinary.flat_map(&:points)).to all(satisfy { |point| point[1] >= 36 })
    returned = scene.routes.find { |route| route.style == :trigger }
    expect(returned.points.first[1]).to eq(268)
    expect(returned.points[1][1]).to be > scene.workflow_grid_bottom
    expect(returned.points.last[1]).to eq(188)
    expect(returned.points).to eq([[562, 268], [562, 292], [394, 292], [394, 188]])
    scene.boxes.each do |box|
      expect(returned.points.each_cons(2).none? { |left, right| SlimGraphR::Layout::Geometry.blocked?(left, right, box.rect) }).to be(true)
    end
    expect(returned.points[1..2]).to all(satisfy { |point| point[1] > scene.workflow_grid_bottom })
  end

  it 'renders arrows behind cards, card semantics, stage headers, payload chips and a truthful legend' do
    svg = process.to_svg(id: 'process-reference')
    expect(svg).to include('data-sgr-process="true"', 'data-sgr-stage="test"', 'data-sgr-stage-number="3"')
    expect(svg).to include('data-sgr-operation="build_app"', 'data-sgr-tool="CSPro"', 'data-sgr-input="FL"', 'data-sgr-output="TB"')
    expect(svg).to include('data-sgr-lane-key="IT"', '>IT<', '>Build app<', '>form + validation<', '>CSPro<')
    expect(svg).to include('data-sgr-payload="FL"', 'data-sgr-payload="TB"')
    expect(svg).to include('data-sgr-workflow-style="accent"', 'marker-end="url(#process-reference-arrow-accent)"')
    expect(svg).to include('data-sgr-workflow-style="trigger"', 'stroke-dasharray="4 3"', '>RETEST<')
    expect(svg).to include('data-sgr-legend-kind="steps"', 'data-sgr-legend-kind="payload"', 'data-sgr-legend-kind="flow"')
    expect(svg.index('data-sgr-workflow-connector=')).to be < svg.index('data-sgr-operation=')
  end

  it 'measures process chips at their rendered font size, clears titles, and right-aligns outputs' do
    graph = process
    scene = graph.layout
    svg = graph.to_svg(id: 'workflow-chip-geometry')
    scene.boxes.each do |box|
      lane = graph.workflow_lanes.find { |item| item.id == box.node.lane }
      role_attrs = svg_attributes(svg_tag(svg, 'rect', 'data-sgr-lane-key', lane.key))
      title_attrs = svg_attributes(svg.scan(/<text\b[^>]*>#{Regexp.escape(box.node.label)}<\/text>/).first)
      expect(role_attrs.fetch('height').to_f).to be >= 16
      expect(role_attrs.fetch('width').to_f).to be >= SlimGraphR::Text.width(lane.key, 12, font: :mono) + 12
      expect(title_attrs.fetch('x').to_f).to be >= role_attrs.fetch('x').to_f + role_attrs.fetch('width').to_f + 6
      expect(title_attrs.fetch('x').to_f + SlimGraphR::Text.width(box.node.label, 14)).to be <= box.right - 4
    end
    svg.scan(/<rect\b[^>]*data-sgr-payload-direction="[^"]+"[^>]*>/).each do |tag|
      attrs = svg_attributes(tag)
      code = attrs.fetch('data-sgr-payload')
      expect(attrs.fetch('height').to_f).to be >= 16
      expect(attrs.fetch('width').to_f).to be >= SlimGraphR::Text.width(code, 12, font: :mono) + 12
      next unless attrs.fetch('data-sgr-payload-direction') == 'output'

      box = scene.boxes.find { |entry| entry.node.output == code }
      expect(attrs.fetch('x').to_f + attrs.fetch('width').to_f).to eq(box.right - 4)
    end
  end

  it 'budgets workflow legend rows from the same dynamic chip geometry the renderer uses' do
    graph = process
    scene = graph.layout
    svg = graph.to_svg(id: 'workflow-legend-geometry')
    payload_rect = svg_attributes(svg_tag(svg, 'rect', 'data-sgr-legend-payload', 'FL'))
    expect(payload_rect.fetch('width').to_f).to be >= SlimGraphR::Text.width('FL', 12, font: :mono) + 12
    expect(payload_rect.fetch('height').to_f).to be >= 16

    scene.workflow_legend_rows.each do |row|
      row[:lines].each do |entries|
        used = entries.sum { |entry| entry.fetch(:width) } + [entries.size - 1, 0].max * 8
        expect(220 + used).to be <= scene.width
        entries.each do |entry|
          symbol_width = SlimGraphR::Layout::Workflow.legend_symbol_width(row[:kind], entry[:code])
          content_width = symbol_width + 8 + SlimGraphR::Text.width(entry[:label], 12, font: :mono)
          expect(content_width).to be <= entry.fetch(:width)
        end
      end
    end
  end

  it 'describes who, what, tools, payloads, focal semantics, ordinary flow and the return trigger' do
    svg = process.to_svg(id: 'process-description')
    expect(svg).to include('Process workflow.', 'Stage 1, Design.', 'Research performs Draft survey')
    expect(svg).to include('tool Excel', 'output FL', 'Stage 3, Test, focal', 'Pilot test, focal')
    expect(svg).to include('Draft survey to Build app', 'Return trigger RETEST from Pilot test to Build app')
  end

  it 'parses strict dedicated JSON with Ruby parity and rejects null/default/cross-type mistakes' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = eval(File.read(File.join(root, 'process.rb'), encoding: 'UTF-8'), binding, File.join(root, 'process.rb'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'process.json'), encoding: 'UTF-8'))
    expect(json.to_svg(id: 'process-parity')).to eq(ruby.to_svg(id: 'process-parity'))

    valid = JSON.parse(File.read(File.join(root, 'swimlane.json'), encoding: 'UTF-8'))
    expect { SlimGraphR::Document.from_json(JSON.generate(valid.merge('nodes' => []))) }.to raise_error(SlimGraphR::Error, /cross-type/i)
    expect { SlimGraphR::Document.from_json(JSON.generate(valid.merge('lanes' => nil))) }.to raise_error(SlimGraphR::Error, /lanes must be an array/i)
    bad = Marshal.load(Marshal.dump(valid))
    bad.fetch('activities').first['unknown'] = true
    expect { SlimGraphR::Document.from_json(JSON.generate(bad)) }.to raise_error(SlimGraphR::Error, /unknown .* fields/i)
    bad = Marshal.load(Marshal.dump(valid))
    bad.fetch('handoffs').first['focal'] = nil
    expect { SlimGraphR::Document.from_json(JSON.generate(bad)) }.to raise_error(SlimGraphR::Error, /focal must be true or false/i)
  end

  it 'supports all four styles, all three themes, title-aware singleton width and Unicode' do
    %i[editorial ruby blueprint mono].each do |style|
      %i[light dark auto].each do |theme|
        svg = swimlane(style: style, theme: theme).to_svg(id: "workflow-#{style}-#{theme}")
        expect(svg).to include(%(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}"))
      end
    end
    singleton = SlimGraphR.diagram(:swimlane, title: 'A singleton workflow title that remains whole') do
      lane :étude, 'Équipe'; stage :résumé, 'Résumé'; activity :café, 'Café ✓', lane: :étude, stage: :résumé
    end
    expect(singleton.layout.width).to be >= SlimGraphR::Text.width(singleton.title, 30, font: singleton.style_profile.heading_font) + 80
    singleton_svg = singleton.to_svg(id: 'unicode-workflow')
    expect(singleton_svg).to include('<title id="unicode-workflow-title">A singleton workflow title that remains whole</title>',
                                     '>A singleton workflow title that remains whole<', 'Équipe', 'Résumé', 'Café ✓')
    expect(singleton_svg.scan(/<text[^>]+class="sgr-title"/).size).to eq(1)
  end

  it 'rejects generic graph vocabulary and workflow vocabulary across diagram types' do
    expect { SlimGraphR.diagram(:swimlane) { node :a } }.to raise_error(SlimGraphR::Error, /use activity/i)
    expect { SlimGraphR.diagram(:process) { edge :a, :b } }.to raise_error(SlimGraphR::Error, /use handoff/i)
    expect { SlimGraphR.diagram(:architecture) { lane :a } }.to raise_error(SlimGraphR::Error, /only.*workflow/i)
    expect { SlimGraphR.diagram(:swimlane) { lane :a; stage :s; operation :x, lane: :a, stage: :s, tool: 'T' } }.to raise_error(SlimGraphR::Error, /operation.*only.*process/i)
  end

  it 'retains every declaration order and renders no invented empty-cell cards' do
    graph = swimlane
    expect(graph.workflow_lanes.map(&:id)).to eq(%w[research it])
    expect(graph.workflow_stages.map(&:id)).to eq(%w[design build test])
    expect(graph.activities.map(&:id)).to eq(%w[draft build_app pilot])
    expect(graph.workflow_handoffs.map { |item| [item.from, item.to] }).to eq([%w[draft build_app], %w[build_app pilot]])
    svg = graph.to_svg(id: 'empty-cells-absent')
    expect(svg.scan('data-sgr-activity=').size).to eq(3)
    expect(svg).not_to include('placeholder')
  end

  it 'deep-freezes process cards, handoffs, trigger, keys, payloads, and every nested string' do
    graph = process
    [graph.workflow_lanes, graph.workflow_stages, graph.operations, graph.workflow_handoffs].each { |list| expect(list).to be_frozen }
    (graph.workflow_lanes + graph.workflow_stages + graph.operations + graph.workflow_handoffs + [graph.workflow_trigger]).each do |record|
      expect(record).to be_frozen
      record.each { |value| expect(value).to be_frozen if value.is_a?(String) }
    end
    expect { graph.workflow_trigger.label << '!' }.to raise_error(FrozenError)
    expect { graph.operations.first.output << '!' }.to raise_error(FrozenError)
  end

  it 'rejects type-specific workflow knobs in the opposite model' do
    expect do
      SlimGraphR.diagram(:swimlane) { lane :a, key: 'A'; stage :s; activity :x, lane: :a, stage: :s }
    end.to raise_error(SlimGraphR::Error, /keys are process-only/i)
    expect do
      SlimGraphR.diagram(:swimlane) { lane :a; stage :s, focal: false; activity :x, lane: :a, stage: :s }
    end.to raise_error(SlimGraphR::Error, /focal stages are process-only/i)
    focused = SlimGraphR.diagram(:swimlane) { lane :a; stage :s; activity :x, lane: :a, stage: :s, focal: true }
    expect(focused.activities.first.focal).to be(true)
    expect do
      SlimGraphR.diagram(:process) do
        lane :a, key: 'A'; stage :s, focal: true; operation :x, lane: :a, stage: :s, tool: 'T', focal: true
        handoff :x, :x, focal: false
      end
    end.to raise_error(SlimGraphR::Error, /handoffs do not accept focal/i)
  end

  it 'rejects the last-stage output and preserves a deliberate payload mismatch without conversion inference' do
    expect do
      SlimGraphR.diagram(:process) do
        lane :a, key: 'A'; stage :one; stage :two, focal: true
        operation :x, lane: :a, stage: :one, tool: 'T'
        operation :y, lane: :a, stage: :two, tool: 'T', output: 'WB', focal: true
      end
    end.to raise_error(SlimGraphR::Error, /last-stage output/i)

    graph = SlimGraphR.diagram(:process) do
      lane :a, key: 'A'; stage :one; stage :two, focal: true
      operation :x, lane: :a, stage: :one, tool: 'T', output: 'DB'
      operation :y, lane: :a, stage: :two, tool: 'T', input: 'TB', focal: true
      handoff :x, :y
    end
    expect(graph.operations.map { |item| [item.input, item.output] }).to eq([[nil, 'DB'], ['TB', nil]])
    expect(graph.to_svg(id: 'payload-mismatch')).not_to include('conversion')
  end

  it 'keeps payload colors independent and legends limited to used payload and effective flow semantics' do
    svg = process.to_svg(id: 'workflow-semantics')
    expect(svg).to include('--sgr-payload-fl:#9c6b50', '--sgr-payload-tb:#b8915a')
    expect(svg).to include('fill="var(--sgr-tint)"', 'fill="var(--sgr-payload-tb)"')
    expect(svg).to include('data-sgr-legend-payload="FL"', 'data-sgr-legend-payload="TB"')
    expect(svg).not_to include('data-sgr-legend-payload="LS"', 'data-sgr-legend-payload="DB"', 'data-sgr-legend-payload="WB"')
    expect(svg).to include('data-sgr-legend-entry="neutral"', 'data-sgr-legend-entry="accent"', 'data-sgr-legend-entry="trigger"')
  end

  it 'routes same-lane, downward, upward, and skipped forward handoffs into the correct target boundary' do
    graph = SlimGraphR.diagram(:swimlane) do
      lane :top; lane :bottom
      stage :one; stage :two; stage :three; stage :four
      activity :a, lane: :top, stage: :one
      activity :b, lane: :bottom, stage: :two
      activity :c, lane: :bottom, stage: :three
      activity :d, lane: :top, stage: :four
      handoff :a, :b
      handoff :b, :c
      handoff :c, :d
    end
    scene = graph.layout
    boxes = scene.boxes.to_h { |box| [box.node.id, box] }
    routes = scene.routes.to_h { |route| [[route.edge.from, route.edge.to], route] }
    expect(routes[%w[a b]].points.first).to eq([boxes['a'].right, boxes['a'].center[1]])
    expect(routes[%w[a b]].points.last).to eq([boxes['b'].center[0], boxes['b'].y])
    expect(routes[%w[b c]].points).to eq([[boxes['b'].right, boxes['b'].center[1]], [boxes['c'].x, boxes['c'].center[1]]])
    expect(routes[%w[c d]].points.last).to eq([boxes['d'].center[0], boxes['d'].bottom])
    skipped = SlimGraphR.diagram(:swimlane) do
      lane :top; lane :bottom
      stage :one; stage :two; stage :three
      activity :x, lane: :top, stage: :one
      activity :z, lane: :bottom, stage: :three
      handoff :x, :z
    end.layout.routes.first
    expect(skipped.points.size).to eq(3)
  end

  it 'rejects card-blocked and crossing forward routes rather than hiding paths' do
    blocked = SlimGraphR.diagram(:swimlane) do
      lane :top; lane :middle; lane :bottom
      stage :one; stage :two; stage :three
      activity :start, lane: :top, stage: :one
      activity :blocker, lane: :middle, stage: :three
      activity :finish, lane: :bottom, stage: :three
      handoff :start, :finish
    end
    expect { blocked.layout }.to raise_error(SlimGraphR::LayoutError, /crosses card blocker/i)

    crossing = SlimGraphR.diagram(:swimlane) do
      lane :top; lane :middle; lane :bottom
      stage :one; stage :two; stage :three; stage :four; stage :five
      activity :a, lane: :top, stage: :one
      activity :b, lane: :middle, stage: :two
      activity :c, lane: :bottom, stage: :four
      activity :d, lane: :bottom, stage: :five
      handoff :a, :c
      handoff :b, :d
    end
    expect { crossing.layout }.to raise_error(SlimGraphR::LayoutError, /routes .* cross/i)

    hidden_fan_out = SlimGraphR.diagram(:swimlane) do
      lane :top; lane :middle; lane :bottom
      stage :one; stage :two; stage :three
      activity :a, lane: :top, stage: :one
      activity :b, lane: :middle, stage: :two
      activity :c, lane: :bottom, stage: :three
      handoff :a, :b
      handoff :a, :c
    end
    expect { hidden_fan_out.layout }.to raise_error(SlimGraphR::LayoutError, /routes .* cross/i)
  end

  it 'keeps boundary payload chips absent and adapts narrow legends by growing rows' do
    graph = SlimGraphR.diagram(:process, title: 'One') do
      lane :a, key: 'A'; stage :one; stage :two, focal: true
      operation :x, lane: :a, stage: :one, tool: 'T', output: 'LS'
      operation :y, lane: :a, stage: :two, tool: 'T', input: 'LS', focal: true
      handoff :x, :y
    end
    svg = graph.to_svg(id: 'workflow-boundaries')
    expect(svg.scan('data-sgr-payload-direction="input"').size).to eq(1)
    expect(svg.scan('data-sgr-payload-direction="output"').size).to eq(1)
    expect(graph.layout.workflow_legend_rows.sum { |row| row[:lines].size }).to be >= 3
  end

  it 'rejects strict process JSON cross-type fields, null defaults, invalid payload scalars, and edge labels/styles' do
    data = JSON.parse(File.read(File.expand_path('../examples/standalone/process.json', __dir__), encoding: 'UTF-8'))
    [
      data.merge('activities' => []),
      data.merge('stages' => data.fetch('stages').map.with_index { |item, index| index.zero? ? item.merge('focal' => nil) : item }),
      data.merge('operations' => data.fetch('operations').map.with_index { |item, index| index.zero? ? item.merge('input' => false) : item }),
      data.merge('handoffs' => [data.fetch('handoffs').first.merge('label' => 'X')]),
      data.merge('handoffs' => [data.fetch('handoffs').first.merge('style' => 'accent')])
    ].each do |invalid|
      expect { SlimGraphR::Document.from_json(JSON.generate(invalid)) }.to raise_error(SlimGraphR::Error)
    end
  end

  it 'rejects a return trigger label that cannot fit inside the reserved band' do
    graph = SlimGraphR.diagram(:process) do
      lane :a, key: 'A'; stage :one; stage :two, focal: true
      operation :x, lane: :a, stage: :one, tool: 'T'
      operation :y, lane: :a, stage: :two, tool: 'T', focal: true
      trigger :y, :x, ('RETRY ' * 45)
    end
    expect { graph.layout }.to raise_error(SlimGraphR::LayoutError, /trigger label does not fit/i)
  end

  it 'grows the scene when a valid first legend entry needs more horizontal room' do
    graph = SlimGraphR.diagram(:swimlane, title: 'One') do
      lane :a
      stage :one, 'ABCDEFGHIJKLMNOPQRSTUVWX'
      activity :x, lane: :a, stage: :one
    end
    scene = graph.layout
    entry = scene.workflow_legend_rows.first.fetch(:lines).first.first
    expect(220 + entry.fetch(:width)).to be <= scene.width
    expect(graph.to_svg(id: 'wide-first-legend')).to include('ABCDEFGHIJKLMNOPQRSTUVWX')
  end
end
