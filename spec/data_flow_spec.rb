# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/document'
require 'open3'
require 'rbconfig'

RSpec.describe 'data-flow diagrams' do
  def svg_attributes(tag)
    tag.scan(/([\w:-]+)="([^"]*)"/).to_h
  end

  def svg_tag(svg, element, attribute, value)
    svg.scan(/<#{element}\b[^>]*>/).find { |tag| svg_attributes(tag)[attribute] == value }
  end

  def data_flow(**options)
    SlimGraphR.diagram(:data_flow, title: 'Declared reporting pipeline', **options) do
      role :admins, 'Data admins', key: 'ADM'
      role :engineers, 'Data engineers', key: 'ENG'
      role :scientists, 'Data scientists', key: 'SCI'
      role :consumers, 'Data consumers', key: 'CON'

      step :collect, 'Collect'
      step :store, 'Store'
      step :prepare, 'Prepare'
      step :analyse, 'Analyse', focal: true
      step :publish, 'Publish'

      transfer :setup, 'Project setup', role: :admins, step: :collect, tool: 'Console'
      transfer :ingest, 'Source ingest', role: :engineers, step: :collect,
               tool: 'SFTP', output: :dataset
      transfer :stage, 'Clean and stage', role: :engineers, step: :prepare,
               tool: 'Trino', input: :dataset, output: :table
      transfer :model, 'Explore and model', role: :scientists, step: :analyse,
               tool: 'Notebook', input: :table, output: :file, focal: true
      transfer :query, 'Query insights', role: :consumers, step: :publish,
               tool: 'Read-only SQL', input: :table

      handoff :setup, :ingest, kind: :trigger
      handoff :stage, :model, kind: :focal, label: 'ANON DATA'
      handoff :model, :query, kind: :publish
    end
  end

  it 'builds dedicated immutable records in exact role, stage, and transfer order' do
    graph = data_flow
    expect(graph.type).to eq(:data_flow)
    expect(graph.data_flow_roles.map { |item| [item.id, item.label, item.key] }).to eq([
      %w[admins Data\ admins ADM], %w[engineers Data\ engineers ENG],
      %w[scientists Data\ scientists SCI], %w[consumers Data\ consumers CON]
    ])
    expect(graph.data_flow_steps.map { |item| [item.id, item.ordinal, item.focal] }).to eq([
      ['collect', 1, false], ['store', 2, false], ['prepare', 3, false],
      ['analyse', 4, true], ['publish', 5, false]
    ])
    expect(graph.data_flow_transfers.map(&:id)).to eq(%w[setup ingest stage model query])
    expect(graph.data_flow_transfers.find { |item| item.id == 'setup' }.then { |item| [item.input, item.output] }).to eq([nil, nil])
    expect(graph.data_flow_handoffs.map { |item| [item.from, item.to, item.kind, item.label] }).to eq([
      ['setup', 'ingest', :trigger, nil], ['stage', 'model', :focal, 'ANON DATA'],
      ['model', 'query', :publish, nil]
    ])
    [graph.data_flow_roles, graph.data_flow_steps, graph.data_flow_transfers, graph.data_flow_handoffs].each do |items|
      expect(items).to be_frozen
      expect(items).to all(be_frozen)
    end
  end

  it 'preserves an authored transfer detail through strict JSON, measured cards, and accessibility text' do
    graph = SlimGraphR.diagram(:data_flow) do
      role :a, key: 'A'; role :b, key: 'B'
      step :one; step :two, focal: true
      transfer :source, 'Source', role: :a, step: :one, tool: 'Ingest', detail: 'events → batch'
      transfer :target, 'Target', role: :b, step: :two, tool: 'SQL', focal: true
      handoff :source, :target, kind: :focal, label: 'DATA'
    end
    expect(graph.data_flow_transfers.first.detail).to eq('events → batch')
    expect(graph.to_svg(id: 'data-flow-detail')).to include('data-sgr-transfer-detail="source"', 'events → batch', 'Source: events → batch by')
    expect { SlimGraphR::Document.from_json(JSON.generate(type: 'data_flow', roles: [], steps: [], transfers: [{ id: 'x', role: 'a', step: 'one', tool: 'X', detail: nil }], handoffs: [])) }
      .to raise_error(SlimGraphR::Error, /detail must be a string/)
  end

  it 'renders transfer details at the metadata floor and measures fit at that same size' do
    graph = SlimGraphR.diagram(:data_flow) do
      role :a, key: 'A'; role :b, key: 'B'
      step :one; step :two, focal: true
      transfer :source, 'Source', role: :a, step: :one, tool: 'Ingest', detail: 'events → batch'
      transfer :target, 'Target', role: :b, step: :two, tool: 'SQL', focal: true
      handoff :source, :target, kind: :focal, label: 'DATA'
    end
    svg = graph.to_svg(id: 'data-flow-detail-floor')
    expect(svg).to match(/\.sgr-data-flow-detail\{[^}]*font-size:12px/)
    expect(svg[/data-sgr-display-scale="([\d.]+)"/, 1].to_f * 12).to be >= 12

    boundary_detail = 'M' * 20
    detail_width = SlimGraphR::Layout::DataFlow::DETAIL_CARD_WIDTH - 16
    expect(SlimGraphR::Text.width(boundary_detail, 10, font: :mono)).to be <= detail_width
    expect(SlimGraphR::Text.width(boundary_detail, 12, font: :mono)).to be > detail_width
    expanded = SlimGraphR.diagram(:data_flow) do
      role :a, key: 'A'; role :b, key: 'B'
      step :one; step :two, focal: true
      transfer :source, 'Source', role: :a, step: :one, tool: 'Ingest', detail: boundary_detail
      transfer :target, 'Target', role: :b, step: :two, tool: 'SQL', focal: true
      handoff :source, :target, kind: :focal, label: 'DATA'
    end
    source_card = expanded.layout.cards.find { |card| card[:transfer].id == 'source' }
    source_step = expanded.layout.steps.find { |step| step[:step].id == 'one' }
    expect(source_card[:width]).to eq(SlimGraphR::Text.grid(SlimGraphR::Text.width(boundary_detail, 12, font: :mono) + 16))
    expect(source_step[:width]).to eq(source_card[:width] + 2 * SlimGraphR::Layout::DataFlow::CARD_INSET)
    expect { expanded.to_svg }.not_to raise_error

    oversized_title = SlimGraphR.diagram(:data_flow) do
      role :a, key: 'A'; role :b, key: 'B'
      step :one; step :two, focal: true
      transfer :source, 'M' * 30, role: :a, step: :one, tool: 'Ingest', detail: 'detail'
      transfer :target, 'Target', role: :b, step: :two, tool: 'SQL', focal: true
      handoff :source, :target, kind: :focal, label: 'DATA'
    end
    expect { oversized_title.to_svg }.to raise_error(SlimGraphR::LayoutError, /title.*measured 164px card/i)

    oversized_tool = SlimGraphR.diagram(:data_flow) do
      role :a, key: 'A'; role :b, key: 'B'
      step :one; step :two, focal: true
      transfer :source, 'Source', role: :a, step: :one, tool: 'M' * 30, detail: 'detail'
      transfer :target, 'Target', role: :b, step: :two, tool: 'SQL', focal: true
      handoff :source, :target, kind: :focal, label: 'DATA'
    end
    expect { oversized_tool.to_svg }.to raise_error(SlimGraphR::LayoutError, /tool.*measured 164px card/i)
  end

  it 'owns mutable string inputs without freezing caller values' do
    role_label = +'Admins'
    role_key = +'ADM'
    step_label = +'Collect'
    transfer_label = +'Setup'
    tool = +'Console'
    focal_label = +'DATA'
    graph = SlimGraphR.diagram(:data_flow) do
      role :a, role_label, key: role_key
      role :b, 'Builders', key: 'BLD'
      step :one, step_label
      step :two, 'Use', focal: true
      transfer :source, transfer_label, role: :a, step: :one, tool: tool
      transfer :target, 'Use data', role: :b, step: :two, tool: 'SQL', focal: true
      handoff :source, :target, kind: :focal, label: focal_label
    end
    [role_label, role_key, step_label, transfer_label, tool, focal_label].each { |value| value << ' changed' }
    expect(graph.data_flow_roles.first.then { |item| [item.label, item.key] }).to eq(%w[Admins ADM])
    expect(graph.data_flow_steps.first.label).to eq('Collect')
    expect(graph.data_flow_transfers.first.then { |item| [item.label, item.tool] }).to eq(%w[Setup Console])
    expect(graph.data_flow_handoffs.first.label).to eq('DATA')
    expect(role_label).not_to be_frozen
  end

  it 'keeps exactly one linked focal step, transfer, and handoff' do
    graph = data_flow
    focal_step = graph.data_flow_steps.find(&:focal)
    focal_transfer = graph.data_flow_transfers.find(&:focal)
    focal_handoff = graph.data_flow_handoffs.find { |item| item.kind == :focal }
    expect([focal_step.id, focal_transfer.step, focal_handoff.to]).to eq(%w[analyse analyse model])
    expect(focal_transfer.id).to eq(focal_handoff.to)

    expect do
      SlimGraphR.diagram(:data_flow) do
        role :a, key: 'A'; role :b, key: 'B'
        step :one; step :two, focal: true
        transfer :x, role: :a, step: :one, tool: 'X'
        transfer :y, role: :b, step: :two, tool: 'Y', focal: true
        handoff :x, :y, kind: :ordinary
      end
    end.to raise_error(SlimGraphR::Error, /exactly one focal handoff/i)

    expect do
      SlimGraphR.diagram(:data_flow) do
        role :a, key: 'A'; role :b, key: 'B'
        step :one, focal: true; step :two
        transfer :x, role: :a, step: :one, tool: 'X', focal: true
        transfer :y, role: :b, step: :two, tool: 'Y'
        handoff :x, :y, kind: :focal, label: 'DATA'
      end
    end.to raise_error(SlimGraphR::Error, /target.*focal transfer.*focal step/i)
  end

  it 'enforces the authored handoff topology and focal-label rules' do
    make = lambda do |kind:, from_role: :a, from_step: :one, to_role: :b, to_step: :two, label: nil|
      SlimGraphR.diagram(:data_flow) do
        role :a, key: 'A'; role :b, key: 'B'; role :c, key: 'C'
        step :one; step :two, focal: true
        transfer :x, role: from_role, step: from_step, tool: 'X'
        transfer :y, role: to_role, step: to_step, tool: 'Y', focal: true
        handoff :x, :y, kind: kind, **(label.nil? ? {} : { label: label })
      end
    end
    expect { make.call(kind: :trigger) }.to raise_error(SlimGraphR::Error, /same step/i)
    expect { make.call(kind: :ordinary, from_step: :two, to_step: :one) }.to raise_error(SlimGraphR::Error, /later step/i)
    expect { make.call(kind: :focal, from_role: :a, to_role: :a, label: 'DATA') }.to raise_error(SlimGraphR::Error, /cross roles/i)
    expect { make.call(kind: :focal) }.to raise_error(SlimGraphR::Error, /requires.*uppercase.*label/i)
    expect { make.call(kind: :focal, label: 'anon data') }.to raise_error(SlimGraphR::Error, /uppercase/i)
    expect { make.call(kind: :ordinary, label: 'DATA') }.to raise_error(SlimGraphR::Error, /only.*focal/i)
    expect { make.call(kind: :bogus) }.to raise_error(SlimGraphR::Error, /ordinary.*trigger.*focal.*publish/i)
  end

  it 'accepts only exact downward same-step triggers' do
    valid = SlimGraphR.diagram(:data_flow) do
      role :a, key: 'A'; role :b, key: 'B'
      step :one; step :two, focal: true
      transfer :x, role: :a, step: :one, tool: 'X'
      transfer :y, role: :b, step: :one, tool: 'Y'
      transfer :z, role: :b, step: :two, tool: 'Z', focal: true
      handoff :x, :y, kind: :trigger
      handoff :x, :z, kind: :focal, label: 'DATA'
    end
    expect(valid.data_flow_handoffs.first.kind).to eq(:trigger)
    expect do
      SlimGraphR.diagram(:data_flow) do
        role :a, key: 'A'; role :b, key: 'B'
        step :one; step :two, focal: true
        transfer :x, role: :b, step: :one, tool: 'X'
        transfer :y, role: :a, step: :one, tool: 'Y'
        transfer :z, role: :b, step: :two, tool: 'Z', focal: true
        handoff :x, :y, kind: :trigger
        handoff :y, :z, kind: :focal, label: 'DATA'
      end
    end.to raise_error(SlimGraphR::Error, /downward role order/i)
  end

  it 'rejects malformed identities, cells, booleans, payloads, references, duplicates, and budgets' do
    base = lambda do |&extra|
      SlimGraphR.diagram(:data_flow) do
        role :a, key: 'A'; role :b, key: 'B'
        step :one; step :two, focal: true
        transfer :x, role: :a, step: :one, tool: 'X'
        transfer :y, role: :b, step: :two, tool: 'Y', focal: true
        handoff :x, :y, kind: :focal, label: 'DATA'
        instance_eval(&extra) if extra
      end
    end
    expect { base.call { role :c, key: 'lower' } }.to raise_error(SlimGraphR::Error, /uppercase.*one to three/i)
    expect { base.call { transfer :z, role: :a, step: :one, tool: 'Z' } }.to raise_error(SlimGraphR::Error, /one transfer.*cell/i)
    expect { base.call { transfer :z, role: :a, step: :two, tool: 'Z', input: :blob } }.to raise_error(SlimGraphR::Error, /web.*dataset.*table.*file.*stream/i)
    expect { base.call { step :three, focal: 'yes' } }.to raise_error(SlimGraphR::Error, /focal must be true or false/i)
    expect { base.call { handoff :missing, :y, kind: :ordinary } }.to raise_error(SlimGraphR::Error, /unknown transfer/i)
    expect { base.call { handoff :x, :y, kind: :focal, label: 'DATA' } }.to raise_error(SlimGraphR::Error, /duplicate handoff/i)
    expect { SlimGraphR.diagram(:data_flow) { role :a, key: 'A' } }.to raise_error(SlimGraphR::Error, /two to four roles/i)
  end

  it 'rejects generic graph and cross-type DSL calls' do
    expect { SlimGraphR.diagram(:data_flow) { node :x } }.to raise_error(SlimGraphR::Error, /role.*step.*transfer.*handoff/i)
    expect { SlimGraphR.diagram(:data_flow) { edge :x, :y } }.to raise_error(SlimGraphR::Error, /handoff/i)
    expect { SlimGraphR.diagram(:architecture) { role :x, key: 'X' } }.to raise_error(SlimGraphR::Error, /only.*data-flow/i)
  end

  it 'round-trips equivalent standalone Ruby and strict JSON byte-for-byte' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = eval(File.read(File.join(root, 'data_flow.rb'), encoding: 'UTF-8'), binding, 'data_flow.rb')
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'data_flow.json'), encoding: 'UTF-8'))
    %i[data_flow_roles data_flow_steps data_flow_transfers data_flow_handoffs].each do |reader|
      expect(json.public_send(reader)).to eq(ruby.public_send(reader))
    end
    expect(json.to_svg(id: 'data-flow-parity')).to eq(ruby.to_svg(id: 'data-flow-parity'))
  end

  it 'registers and renders standalone Ruby and JSON through the executable' do
    root = File.expand_path('..', __dir__)
    executable = File.join(root, 'exe/slimgraph')
    types, types_error, types_status = Open3.capture3(RbConfig.ruby, '-I', File.join(root, 'lib'), executable, 'types')
    expect(types_status).to be_success
    expect(types_error).to be_empty
    expect(types.lines.map(&:strip)).to include('data_flow')
    %w[rb json].each do |extension|
      source = File.join(root, "examples/standalone/data_flow.#{extension}")
      out, error, status = Open3.capture3(RbConfig.ruby, '-I', File.join(root, 'lib'), executable, 'render', source)
      expect(status).to be_success, error
      expect(out).to include('data-sgr-data-flow="true"', 'data-sgr-focal-label-mask="true"', 'input not declared')
      expect(error).to be_empty
    end
  end

  it 'rejects unknown, cross-type, null, malformed, and wrongly typed strict JSON fields' do
    root = File.expand_path('../examples/standalone/data_flow.json', __dir__)
    data = JSON.parse(File.read(root, encoding: 'UTF-8'))
    invalid = [
      data.merge('nodes' => []),
      data.merge('direction' => 'down'),
      data.merge('roles' => nil),
      data.merge('roles' => [data.fetch('roles').first.merge('key' => nil)]),
      data.merge('steps' => [data.fetch('steps').first.merge('focal' => 'yes')]),
      data.merge('transfers' => [data.fetch('transfers').first.merge('input' => nil)]),
      data.merge('handoffs' => [data.fetch('handoffs').first.merge('label' => nil)]),
      data.merge('handoffs' => [data.fetch('handoffs').first.merge('protocol' => 'SFTP')])
    ]
    invalid.each { |value| expect { SlimGraphR::Document.from_json(JSON.generate(value)) }.to raise_error(SlimGraphR::Error) }
  end

  it 'renders a measured role-stage grid with fixed cards, exact badges, and empty cells absent' do
    svg = data_flow.to_svg(id: 'data-flow-grid')
    expect(svg).to include('data-sgr-data-flow="true"', 'data-sgr-role="admins"', 'data-sgr-step="analyse"')
    expect(svg).to match(/<rect[^>]*width="152"[^>]*height="72"[^>]*data-sgr-transfer="model"/)
    expect(svg).to include('data-sgr-role-key="SCI"', 'data-sgr-payload-side="input"', 'data-sgr-payload="table"',
                           'data-sgr-payload-side="output"', 'data-sgr-payload="file"')
    expect(svg).not_to include('data-sgr-cell="admins:store"', 'data-sgr-cell="consumers:collect"')
    expect(svg).to include('letter-spacing="1.2"')
  end

  it 'measures twelve-pixel role and payload chips and keeps adjacent titles clear' do
    graph = data_flow
    svg = graph.to_svg(id: 'data-flow-chip-geometry')
    graph.layout.cards.each do |card|
      role = graph.data_flow_roles.find { |item| item.id == card[:transfer].role }
      role_attrs = svg.scan(/<rect\b[^>]*data-sgr-role-key="#{Regexp.escape(role.key)}"[^>]*>/)
        .map { |tag| svg_attributes(tag) }
        .find { |attrs| attrs.fetch('x').to_f == card[:x] + 6 }
      expect(role_attrs.fetch('width').to_f).to be >= SlimGraphR::Text.width(role.key, 12, font: :mono) + 12
      expect(role_attrs.fetch('height').to_f).to be >= 16
      next if card[:transfer].detail

      first_line = card[:title_lines].first
      title_tag = svg.scan(/<text\b[^>]*>#{Regexp.escape(first_line)}<\/text>/).first
      title_attrs = svg_attributes(title_tag)
      expect(title_attrs.fetch('x').to_f).to be >= role_attrs.fetch('x').to_f + role_attrs.fetch('width').to_f + 4
      expect(title_attrs.fetch('x').to_f + SlimGraphR::Text.width(first_line, 14)).to be <= card[:x] + card[:width] - 4
    end
    svg.scan(/<rect\b[^>]*data-sgr-payload-side="[^"]+"[^>]*>/).each do |tag|
      attrs = svg_attributes(tag)
      label = attrs.fetch('data-sgr-payload').upcase
      expect(attrs.fetch('width').to_f).to be >= SlimGraphR::Text.width(label, 12, font: :mono) + 12
      expect(attrs.fetch('height').to_f).to be >= 16
    end
  end

  it 'uses the same measured advances for data-flow legend rendering and width budgets' do
    graph = data_flow
    scene = graph.layout
    svg = graph.to_svg(id: 'data-flow-legend-geometry')
    payload_origins = scene.legend[:payloads].to_h do |payload|
      tag = svg_tag(svg, 'circle', 'data-sgr-legend-payload', payload.to_s)
      [payload, svg_attributes(tag).fetch('cx').to_f - 5]
    end
    payload_pairs = scene.legend[:payloads].each_cons(2)
    payload_pairs.each do |left, right|
      expect(payload_origins.fetch(right) - payload_origins.fetch(left)).to eq(
        SlimGraphR::Layout::DataFlow.payload_legend_entry_width(left)
      )
    end
    expect(scene.legend[:payloads].sum { |payload| SlimGraphR::Layout::DataFlow.payload_legend_entry_width(payload) })
      .to be <= scene.width - 40
    expect(scene.legend[:kinds].sum { |kind| SlimGraphR::Layout::DataFlow.handoff_legend_entry_width(kind) })
      .to be <= scene.width - 40
  end

  it 'paints distinct orthogonal ports and routes before cards with focal label clearance' do
    svg = data_flow.to_svg(id: 'data-flow-routes')
    expect(svg.scan('data-sgr-data-flow-route=').size).to eq(3)
    expect(svg.scan('data-sgr-source-port=').size).to eq(3)
    expect(svg.scan('data-sgr-target-port=').size).to eq(3)
    expect(svg).not_to match(/data-sgr-data-flow-route=[^>]+ d="[^"]*[A-Za-z][^"]*"/)
    expect(svg).to include('data-sgr-handoff-kind="trigger"', 'data-sgr-handoff-kind="focal"',
                           'data-sgr-handoff-kind="publish"', 'data-sgr-focal-label-mask="true"',
                           'data-sgr-label-gap="8"', 'data-sgr-rounded-bends="true"')
    expect(svg.index('data-sgr-data-flow-route=')).to be < svg.index('data-sgr-transfer=')
    route_commands = svg.scan(/data-sgr-route-segment="\d+" d="([^"]+)"/).flatten
    expect(route_commands).to all(match(/\AM [\d.]+ [\d.]+(?: [HVQ] [\d. ]+)+\z/))
    expect(route_commands).to all(satisfy { |command| !command.include?(' L ') && !command.include?(' C ') })
  end

  it 'never serializes a direct trigger away from its declared target port' do
    scene = data_flow.layout
    trigger = scene.routes.find { |route| route[:handoff].kind == :trigger }
    expect(trigger[:points].first).to eq(trigger[:source_port])
    expect(trigger[:points].last).to eq(trigger[:target_port])
    expect(trigger[:source_port][0]).to eq(trigger[:target_port][0])

    fanout = SlimGraphR.diagram(:data_flow) do
      role :a, key: 'A'; role :b, key: 'B'; role :c, key: 'C'
      step :one; step :two, focal: true
      transfer :x, role: :a, step: :one, tool: 'X'
      transfer :y, role: :b, step: :one, tool: 'Y'
      transfer :z, role: :c, step: :one, tool: 'Z'
      transfer :focus, role: :c, step: :two, tool: 'F', focal: true
      handoff :x, :y, kind: :trigger
      handoff :x, :z, kind: :trigger
      handoff :x, :focus, kind: :focal, label: 'DATA'
    end
    expect { fanout.to_svg }.to raise_error(
      SlimGraphR::LayoutError, /direct-vertical trigger ports.*align|trigger route.*blocked.*split/i
    )
  end

  it 'lists only used payload forms and handoff kinds in the legend' do
    svg = data_flow.to_svg(id: 'data-flow-legend')
    expect(svg).to include('data-sgr-legend-payload="dataset"', 'data-sgr-legend-payload="table"',
                           'data-sgr-legend-payload="file"', 'data-sgr-legend-handoff="trigger"',
                           'data-sgr-legend-handoff="focal"', 'data-sgr-legend-handoff="publish"')
    expect(svg).not_to include('data-sgr-legend-payload="web"', 'data-sgr-legend-payload="stream"',
                               'data-sgr-legend-handoff="ordinary"')
  end

  it 'generates all declared semantics without inferring conversions or omitted handoffs' do
    svg = data_flow.to_svg(id: 'data-flow-description')
    expect(svg).to include('Roles in order: Data admins; Data engineers; Data scientists; Data consumers.',
                           'Stages in order: 1 Collect; 2 Store; 3 Prepare; 4 Analyse, focal; 5 Publish.',
                           'Project setup by Data admins at Collect using Console; input not declared; output not declared.',
                           'Clean and stage by Data engineers at Prepare using Trino; input dataset; output table.',
                           'focal handoff from Clean and stage to Explore and model, label ANON DATA')
    expect(svg).not_to include('dataset converts to table', 'Store transfer', 'inferred')
    custom = data_flow(description: 'Author supplied replacement.').to_svg(id: 'data-flow-custom')
    expect(custom).to include('<desc id="data-flow-custom-desc">Author supplied replacement.</desc>')
    expect(custom).not_to include('Roles in order:')
  end

  it 'uses fixed style-aware payload tokens across all four light and dark profiles' do
    SlimGraphR::Style.names.product(%i[light dark]).each do |style, theme|
      svg = data_flow(style: style, theme: theme).to_svg(id: "data-flow-#{style}-#{theme}")
      expect(svg).to include(%(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}"),
                             '--sgr-payload-dataset:', '--sgr-payload-table:', '--sgr-payload-file:')
    end
  end

  it 'gives the focal stage an effective paper foreground over the accent chip' do
    SlimGraphR::Style.names.product(%i[light dark]).each do |style, theme|
      svg = data_flow(style: style, theme: theme).to_svg(id: "focal-stage-#{style}-#{theme}")
      expect(svg).to include('class="sgr-data-flow-step sgr-data-flow-step-focal"')
      expect(svg).to include('.sgr-data-flow-step.sgr-data-flow-step-focal{fill:var(--sgr-paper)}')
    end
  end

  it 'raises actionable layout errors for measured text, blocked routes, port density, and legend fit' do
    long_role = data_flow
    long_role.data_flow_roles.first.label # prove fixture materialized before independent failures
    expect do
      SlimGraphR.diagram(:data_flow) do
        role :a, 'A' * 80, key: 'A'; role :b, key: 'B'
        step :one; step :two, focal: true
        transfer :x, role: :a, step: :one, tool: 'X'
        transfer :y, role: :b, step: :two, tool: 'Y', focal: true
        handoff :x, :y, kind: :focal, label: 'DATA'
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /role label.*shorten.*split/i)

    expect do
      SlimGraphR.diagram(:data_flow) do
        role :a, key: 'A'; role :b, key: 'B'
        step :one; step :two, focal: true
        transfer :x, 'An exceptionally long transfer title that cannot fit', role: :a, step: :one, tool: 'X'
        transfer :y, role: :b, step: :two, tool: 'Y', focal: true
        handoff :x, :y, kind: :focal, label: 'DATA'
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /transfer title.*measured 152px card.*shorten/i)

    expect do
      SlimGraphR.diagram(:data_flow) do
        role :a, key: 'A'; role :b, key: 'B'; role :c, key: 'C'
        step :one; step :two, focal: true
        transfer :x, role: :a, step: :one, tool: 'X'
        transfer :block, role: :b, step: :two, tool: 'Block'
        transfer :y, role: :c, step: :two, tool: 'Y', focal: true
        handoff :x, :y, kind: :focal, label: 'DATA'
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /focal.*arrival.*blocked.*split/i)
  end
end
