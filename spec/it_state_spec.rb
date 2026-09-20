# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'IT current-state diagrams' do
  def atlas_landscape
    SlimGraphR.diagram(:it_state, title: 'Current IT landscape', subtitle: 'Before the platform') do
      phase(:collection, 'Collection') { system :survey, 'Survey app', detail: 'PostgreSQL' }
      phase(:processing, 'Processing') do
        system :drive, 'Shared drive', detail: 'No version control', state: :pain_point
      end
      phase(:publication, 'Publication') { system :portal, 'Legacy portal', state: :pain_point }
      handoff :survey, :drive, 'CSV', style: :link
      handoff :drive, :portal, 'EXCEL', dashed: true
      crosscut :identity, 'Identity', detail: 'LDAP / SSO'
    end
  end

  def reference_landscape(**options)
    SlimGraphR.diagram(
      :it_state,
      title: 'Current IT Landscape',
      subtitle: 'Data pipeline before the platform',
      eyebrow: 'NatStat · Before the platform',
      **options
    ) do
      phase :collection, 'COLLECTION' do
        system :survey, 'Survey Solutions', detail: 'CAPI · PostgreSQL'
        system :registry, 'Civil Registry', detail: 'External · CRVS data', state: :external
      end
      phase :processing, 'PROCESSING' do
        system :drive, 'Shared Drive', detail: 'No version control', state: :pain_point
        system :analysts, 'Analyst Machines', detail: 'SPSS · SAS · Stata · Excel'
      end
      phase :dissemination, 'DISSEMINATION' do
        system :portal, 'Legacy Portal', detail: 'Manual bottleneck', state: :pain_point
        system :website, 'NatStat Website', detail: 'Public · static pages'
      end

      handoff :survey, :drive, 'CSV', style: :link
      handoff :registry, :drive, 'EXCEL', style: :link, dashed: true
      handoff :drive, :analysts, 'COPY', style: :neutral, dashed: true
      handoff :analysts, :portal, 'EXCEL', style: :link
      handoff :portal, :website, 'WEB'
      crosscut :identity, 'Identity Manager', detail: 'Active Directory · LDAP · SSO'
    end
  end

  it 'fits the exact atlas landscape while containing phases, systems, hand-offs, and footer copy' do
    scene = atlas_landscape.layout
    expect(scene.width).to eq(992)
    expect(atlas_landscape.to_svg(id: 'atlas-it-state')).to include(
      'viewBox="0 0 992 ', 'width="1323"', 'min-width:1323px'
    )
    scene.boxes.each do |box|
      zone = scene.zones.find { |item| item[:id] == box.node.zone }
      expect(box.rect).to satisfy do |left, top, right, bottom|
        left > zone[:rect][0] && top > zone[:rect][1] && right < zone[:rect][2] && bottom < zone[:rect][3]
      end
    end
    scene.routes.each do |route|
      expect(route.points).to all(satisfy { |x, y| x.between?(0, scene.width) && y.between?(0, scene.height) })
      expect(SlimGraphR::Layout::Geometry.overlaps?(route.label_box[:rect], scene.footers.first[:rect])).to be(false)
    end
  end

  it 'models ordered phases, explicitly stated system state, hand-offs and cross-cutting services' do
    graph = reference_landscape
    expect(graph.direction).to eq(:right)
    expect([graph.eyebrow, graph.subtitle]).to eq(['NatStat · Before the platform', 'Data pipeline before the platform'])
    expect(graph.phases.map { |phase| [phase.id, phase.label] }).to eq([
      %w[collection COLLECTION], %w[processing PROCESSING], %w[dissemination DISSEMINATION]
    ])
    expect(graph.nodes.map { |system| [system.id, system.zone, system.kind] }).to include(
      ['registry', 'collection', :external], ['drive', 'processing', :pain_point]
    )
    expect(graph.edges.map { |item| [item.label, item.kind, item.dashed] }).to include(
      ['CSV', :link, false], ['COPY', :neutral, true]
    )
    expect(graph.crosscuts.map { |item| [item.id, item.label, item.detail] }).to eq([
      ['identity', 'Identity Manager', 'Active Directory · LDAP · SSO']
    ])
  end

  it 'keeps standalone Ruby and strict JSON examples equivalent' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = eval(File.read(File.join(root, 'it_state.rb')), binding, File.join(root, 'it_state.rb'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'it_state.json')))
    expect(json.to_svg(id: 'it-state-parity')).to eq(ruby.to_svg(id: 'it-state-parity'))
  end

  it 'parses the closed JSON schema with documented defaults' do
    data = {
      type: 'it_state', title: 'Before', subtitle: 'Current exchange', eyebrow: 'Legacy estate',
      phases: [
        { id: 'collect', systems: [{ id: 'forms', detail: 'Email intake' }] },
        { id: 'process', systems: [{ id: 'drive', state: 'pain_point' }] }
      ],
      handoffs: [{ from: 'forms', to: 'drive', label: 'email', dashed: true }],
      crosscuts: [{ id: 'identity', label: 'Identity', detail: 'LDAP' }]
    }
    graph = SlimGraphR::Document.from_json(JSON.generate(data))
    expect(graph.nodes.first.label).to eq('Forms')
    expect(graph.nodes.first.kind).to eq(:standard)
    expect(graph.edges.first.label).to eq('EMAIL')
    expect(graph.edges.first.kind).to eq(:neutral)
    expect(graph.direction).to eq(:right)
  end

  it 'keeps IT-state vocabulary out of other diagram types and generic graph vocabulary out of IT state' do
    expect { SlimGraphR.diagram(:architecture, subtitle: 'No') { node :a } }.to raise_error(SlimGraphR::Error, /subtitle.*only.*IT current-state/i)
    expect { SlimGraphR.diagram(:architecture) { phase(:a) {} } }.to raise_error(SlimGraphR::Error, /phase.*only.*IT current-state/i)
    expect { SlimGraphR.diagram(:it_state) { node :a } }.to raise_error(SlimGraphR::Error, /use system.*phase/i)
    expect do
      SlimGraphR.diagram(:it_state) { phase(:a) { system :x }; phase(:b) { system :y }; edge :x, :y }
    end.to raise_error(SlimGraphR::Error, /use handoff/i)
  end

  it 'validates nesting, IDs, states, styles and booleans in Ruby' do
    expect { SlimGraphR.diagram(:it_state) { system :a } }.to raise_error(SlimGraphR::Error, /inside a phase/i)
    expect do
      SlimGraphR.diagram(:it_state) { phase(:a) { phase(:b) { system :x } } }
    end.to raise_error(SlimGraphR::Error, /cannot nest/i)
    expect do
      SlimGraphR.diagram(:it_state) { phase(:a) { system :x, state: :old }; phase(:b) { system :y } }
    end.to raise_error(SlimGraphR::Error, /standard, external, pain_point/)
    expect do
      SlimGraphR.diagram(:it_state) { phase(:a) { system :x }; phase(:b) { system :y }; handoff :x, :y, 'X', style: :blue }
    end.to raise_error(SlimGraphR::Error, /neutral, link, accent/)
    expect do
      SlimGraphR.diagram(:it_state) { phase(:a) { system :x }; phase(:b) { system :y }; handoff :x, :y, 'X', dashed: 'yes' }
    end.to raise_error(SlimGraphR::Error, /dashed must be true or false/)
  end

  it 'enforces current-state budgets and counts transformed uppercase labels' do
    expect do
      SlimGraphR.diagram(:it_state) { phase(:one) { system :a } }
    end.to raise_error(SlimGraphR::Error, /two to four phases/i)
    expect do
      SlimGraphR.diagram(:it_state) do
        phase(:one) { 6.times { |i| system "a#{i}" } }
        phase(:two) { system :b }
      end
    end.to raise_error(SlimGraphR::Error, /one to five systems/i)
    expect do
      SlimGraphR.diagram(:it_state) do
        phase(:one) { system :a, state: :pain_point; system :b, state: :pain_point }
        phase(:two) { system :c, state: :pain_point }
      end
    end.to raise_error(SlimGraphR::Error, /two pain-point systems/i)
    expect do
      SlimGraphR.diagram(:it_state) { phase('one', 'abcdefghijklmß') { system :a }; phase(:two) { system :b } }
    end.to raise_error(SlimGraphR::Error, /14 characters.*uppercase/i)
    expect do
      SlimGraphR.diagram(:it_state) do
        phase(:one) { system :a }
        phase(:two) { system :b }
        handoff :a, :b, '1234567ß'
      end
    end.to raise_error(SlimGraphR::Error, /eight characters.*uppercase/i)
  end

  it 'permits backward hand-offs only when dashed and touching an external system' do
    valid = SlimGraphR.diagram(:it_state) do
      phase(:left) { system :external_source, state: :external }
      phase(:right) { system :inside }
      handoff :inside, :external_source, 'PULL', dashed: true
    end
    expect(valid.edges.first.dashed).to be(true)
    expect do
      SlimGraphR.diagram(:it_state) do
        phase(:left) { system :inside }
        phase(:right) { system :later }
        handoff :later, :inside, 'COPY', dashed: true
      end
    end.to raise_error(SlimGraphR::Error, /backward.*external/i)
    expect do
      SlimGraphR.diagram(:it_state) do
        phase(:left) { system :outside, state: :external }
        phase(:right) { system :later }
        handoff :later, :outside, 'PULL'
      end
    end.to raise_error(SlimGraphR::Error, /backward.*dashed/i)
  end

  it 'uses declaration order for same-phase backward hand-offs and accepts either external endpoint' do
    external_target = SlimGraphR.diagram(:it_state) do
      phase(:same) { system :z, state: :external; system :a }
      phase(:later) { system :finish }
      handoff :a, :z, 'PULL', dashed: true
    end
    external_source = SlimGraphR.diagram(:it_state) do
      phase(:same) { system :z; system :a, state: :external }
      phase(:later) { system :finish }
      handoff :a, :z, 'PUSH', dashed: true
    end
    expect([external_target.edges.first.dashed, external_source.edges.first.dashed]).to eq([true, true])
    expect do
      SlimGraphR.diagram(:it_state) do
        phase(:same) { system :z, state: :external; system :a }
        phase(:later) { system :finish }
        handoff :a, :z, 'PULL'
      end
    end.to raise_error(SlimGraphR::Error, /backward.*dashed/i)
    expect do
      SlimGraphR.diagram(:it_state) do
        phase(:same) { system :z; system :a }
        phase(:later) { system :finish }
        handoff :a, :z, 'PULL', dashed: true
      end
    end.to raise_error(SlimGraphR::Error, /backward.*external/i)
  end

  it 'freezes the closed model and enforces global IDs, endpoint validity and top-level declarations' do
    graph = reference_landscape
    [graph.phases, graph.nodes, graph.edges, graph.crosscuts].each { |items| expect(items).to be_frozen }
    (graph.phases + graph.nodes + graph.edges + graph.crosscuts).each { |item| expect(item).to be_frozen }
    expect(graph.phases.first.label).to be_frozen
    expect(graph.edges.first.label).to be_frozen
    expect { graph.phases.first.label << '!' }.to raise_error(FrozenError)
    expect { graph.edges.first.label << '!' }.to raise_error(FrozenError)
    expect do
      SlimGraphR.diagram(:it_state) do
        phase(:same) do
          begin
            phase(:nested) { system :bad }
          rescue SlimGraphR::Error
            system :restored
          end
        end
        phase(:other) { system :ok }
      end
    end.not_to raise_error
    expect do
      SlimGraphR.diagram(:it_state) do
        phase(:same) { system :same }
        phase(:other) { system :ok }
      end
    end.to raise_error(SlimGraphR::Error, /unique across phases, systems, and cross-cuts/)
    expect do
      SlimGraphR.diagram(:it_state) do
        phase(:one) { system :a; crosscut :bad }
        phase(:two) { system :b }
      end
    end.to raise_error(SlimGraphR::Error, /top level/i)
    expect do
      SlimGraphR.diagram(:it_state) do
        phase(:one) { system :a }
        phase(:two) { system :b }
        handoff :a, :missing, 'CSV'
      end
    end.to raise_error(SlimGraphR::Error, /Unknown IT current-state system: missing/)
    expect do
      SlimGraphR.diagram(:it_state) do
        phase(:one) { system :a }
        phase(:two) { system :b }
        handoff :a, :b, 'CSV'
        handoff :a, :b, 'EMAIL'
      end
    end.to raise_error(SlimGraphR::Error, /Duplicate hand-offs/)
  end

  it 'lays out ordered phase columns, contained systems, source-bound labels and footer bars' do
    graph = reference_landscape
    scene = graph.layout
    expect(scene.zones.map { |zone| zone[:id] }).to eq(%w[collection processing dissemination])
    expect(scene.zones.map { |zone| zone[:rect][0] }).to eq(scene.zones.map { |zone| zone[:rect][0] }.sort)
    scene.zones.combination(2) do |left, right|
      expect(SlimGraphR::Layout::Geometry.overlaps?(left[:rect], right[:rect])).to be(false)
    end
    scene.boxes.each do |box|
      zone = scene.zones.find { |item| item[:id] == box.node.zone }
      expect(box.x).to be > zone[:rect][0]
      expect(box.right).to be < zone[:rect][2]
      expect(box.y).to be > zone[:rect][1]
      expect(box.bottom).to be < zone[:rect][3]
    end
    scene.boxes.combination(2) do |left, right|
      expect(SlimGraphR::Layout::Geometry.overlaps?(left.rect, right.rect)).to be(false)
    end
    scene.zones.each do |zone|
      header = zone[:header_rect]
      expect(header[0]).to be >= zone[:rect][0]
      expect(header[2]).to be <= zone[:rect][2]
      expect(header[1]).to be <= zone[:rect][1]
      expect(header[3]).to be > zone[:rect][1]
    end
    scene.routes.each do |route|
      source = scene.boxes.find { |box| box.node.id == route.edge.from }
      target = scene.boxes.find { |box| box.node.id == route.edge.to }
      expect(route.points.first).to satisfy { |point| [source.x, source.right].include?(point[0]) || [source.y, source.bottom].include?(point[1]) }
      expect(route.points.last).to satisfy { |point| [target.x, target.right].include?(point[0]) || [target.y, target.bottom].include?(point[1]) }
      finish, previous = route.points.last, route.points[-2]
      if finish[0] == target.x
        expect(previous[0]).to be < finish[0]
        expect(finish[1]).to be_between(target.y, target.bottom)
      elsif finish[0] == target.right
        expect(previous[0]).to be > finish[0]
        expect(finish[1]).to be_between(target.y, target.bottom)
      elsif finish[1] == target.y
        expect(previous[1]).to be < finish[1]
        expect(finish[0]).to be_between(target.x, target.right)
      elsif finish[1] == target.bottom
        expect(previous[1]).to be > finish[1]
        expect(finish[0]).to be_between(target.x, target.right)
      else
        raise "hand-off does not touch target #{route.edge.to}"
      end
      expect(route.label_box[:rect][3] - route.label_box[:rect][1]).to eq(18)
      first_segment = route.points.first(2)
      label = route.label_box[:rect]
      if first_segment[0][1] == first_segment[1][1]
        expect(label[0]).to be >= [first_segment[0][0], first_segment[1][0]].min
        expect(label[2]).to be <= [first_segment[0][0], first_segment[1][0]].max
        distance = [first_segment[0][1] - label[3], label[1] - first_segment[0][1]].max
      else
        expect(label[1]).to be >= [first_segment[0][1], first_segment[1][1]].min
        expect(label[3]).to be <= [first_segment[0][1], first_segment[1][1]].max
        distance = [first_segment[0][0] - label[2], label[0] - first_segment[0][0]].max
      end
      expect(distance).to be >= 5
      expect(distance).to be <= 6
    end
    expect(scene.footers.map { |item| item[:crosscut].id }).to eq(['identity'])
    expect(scene.legend).to eq(%i[accent dashed pain_point external])
    phase_bottom = scene.zones.map { |zone| zone[:rect][3] }.max
    scene.footers.each do |footer|
      expect(footer[:rect][0]).to eq(SlimGraphR::Layout::ItState::MARGIN)
      expect(footer[:rect][2]).to eq(scene.width - SlimGraphR::Layout::ItState::MARGIN)
      expect(footer[:rect][1]).to be > phase_bottom
    end
    expect(scene.legend_rect[0]).to eq(SlimGraphR::Layout::ItState::MARGIN)
    expect(scene.legend_rect[2]).to eq(scene.width - SlimGraphR::Layout::ItState::MARGIN)
    expect(scene.legend_rect[1]).to be > (scene.footers.last || { rect: [0, 0, 0, phase_bottom] })[:rect][3]

    drive_ports = scene.routes.select { |route| route.edge.to == 'drive' }.map { |route| route.points.last[1] }.sort
    expect(drive_ports.each_cons(2).map { |a, b| b - a }).to all(be >= 12)
  end


  it 'derives neutral and link legend entries only from effective non-focal hand-off styles' do
    graph = SlimGraphR.diagram(:it_state) do
      phase(:left) { system :a; system :b }
      phase(:right) { system :c }
      handoff :a, :b, 'COPY'
      handoff :b, :c, 'CSV', style: :link
    end
    expect(graph.layout.legend).to eq(%i[neutral link])
  end

  it 'measures long cross-cut labels and wraps a full semantic legend into contained rows' do
    graph = SlimGraphR.diagram(:it_state) do
      phase(:left) { system :external, state: :external; system :plain; system :neutral_target }
      phase(:right) { system :link_target; system :pain, state: :pain_point }
      handoff :external, :plain, 'COPY', dashed: true
      handoff :plain, :neutral_target, 'LOAD'
      handoff :neutral_target, :link_target, 'CSV', style: :link
      handoff :link_target, :pain, 'COPY'
      crosscut :long_service, 'A layer-wide service name ' * 11, detail: 'Logs · metrics · alerts'
    end
    scene = graph.layout
    footer = scene.footers.first
    final_label_baseline = footer[:label_y] + (footer[:label_lines].size - 1) * 20
    final_detail_baseline = footer[:detail_y] + (footer[:detail_lines].size - 1) * 16
    expect([final_label_baseline, final_detail_baseline].max).to be <= footer[:rect][3] - 12
    expect(scene.legend_entries.map { |entry| entry[:kind] }).to eq(scene.legend)
    expect(scene.legend_entries.map { |entry| entry[:rect][1] }.uniq.size).to be >= 2
    scene.legend_entries.each do |entry|
      expect(entry[:rect][0]).to be >= scene.legend_rect[0]
      expect(entry[:rect][2]).to be <= scene.legend_rect[2]
      expect(entry[:rect][3]).to be <= scene.legend_rect[3]
    end
  end

  it 'keeps routes out of non-endpoint systems and cross-cut footer geometry' do
    scene = reference_landscape.layout
    scene.routes.each do |route|
      route.points.each_cons(2) do |from, to|
        scene.boxes.reject { |box| [route.edge.from, route.edge.to].include?(box.node.id) }.each do |box|
          expect(SlimGraphR::Layout::Geometry.blocked?(from, to, box.rect)).to be(false)
        end
        reserved = scene.zones.map { |zone| zone[:header_rect] } +
          scene.footers.map { |footer| footer[:rect] } + [scene.legend_rect]
        reserved.each { |rect| expect(SlimGraphR::Layout::Geometry.blocked?(from, to, rect)).to be(false) }
      end
      labels = scene.routes.map(&:label_box)
      blockers = scene.boxes.map(&:rect) + scene.zones.map { |zone| zone[:header_rect] } +
        scene.footers.map { |footer| footer[:rect] } + [scene.legend_rect]
      blockers.each { |rect| expect(SlimGraphR::Layout::Geometry.overlaps?(route.label_box[:rect], rect)).to be(false) }
      scene.routes.each do |other|
        other.points.each_cons(2) do |from, to|
          expect(SlimGraphR::Layout::Geometry.blocked?(from, to, route.label_box[:rect])).to be(false)
        end
      end
      labels.reject { |label| label.equal?(route.label_box) }.each do |label|
        expect(SlimGraphR::Layout::Geometry.overlaps?(route.label_box[:rect], label[:rect])).to be(false)
      end
    end
  end

  it 'lays out permitted same-phase and cross-phase backward external hand-offs' do
    graph = SlimGraphR.diagram(:it_state) do
      phase(:left) { system :outside, state: :external; system :inside }
      phase(:right) { system :later }
      handoff :inside, :outside, 'PULL', dashed: true
      handoff :later, :outside, 'SYNC', dashed: true
    end
    scene = graph.layout
    expect(scene.routes.size).to eq(2)
    scene.routes.each do |route|
      target = scene.boxes.find { |box| box.node.id == route.edge.to }
      finish, previous = route.points.last, route.points[-2]
      visible_entry =
        (finish[0] == target.right && previous[0] > finish[0]) ||
        (finish[1] == target.bottom && previous[1] > finish[1])
      expect(visible_entry).to be(true)
    end
  end

  it 'renders explicit current-state semantics, effective focal styles and accessible defining parts' do
    graph = reference_landscape
    svg = graph.to_svg(id: 'it-state-example')
    expect(svg).to include('data-sgr-it-state="true"', 'data-sgr-eyebrow="true"', 'data-sgr-subtitle="true"')
    expect(svg).to include('data-sgr-phase="collection"', 'data-sgr-system-state="external"', 'data-sgr-system-state="pain_point"')
    expect(svg).to include('data-sgr-crosscut="identity"', 'data-sgr-legend="true"')
    expect(svg).to include('data-sgr-handoff="survey-drive"', 'data-sgr-handoff-style="accent"')
    expect(svg).to include('data-sgr-handoff="registry-drive"', 'stroke-dasharray="4 3"')
    expect(svg).to include('COLLECTION contains Survey Solutions', 'Shared Drive, pain point',
                           'Survey Solutions to Shared Drive: CSV', 'Cross-cutting service: Identity Manager')
    expect(svg.index('data-sgr-connector=')).to be < svg.index('data-sgr-system=')
    xml = REXML::Document.new(svg)
    graph.edges.each do |edge|
      endpoints = graph.nodes.select { |node| [edge.from, edge.to].include?(node.id) }
      next unless endpoints.any? { |node| node.kind == :pain_point }
      path = REXML::XPath.first(xml, "//*[@data-sgr-handoff='#{edge.from}-#{edge.to}']")
      expect(path.attributes['data-sgr-handoff-requested-style']).to eq(edge.kind.to_s)
      expect(path.attributes['data-sgr-handoff-style']).to eq('accent')
    end
    description = REXML::XPath.first(xml, "//*[local-name()='desc']").text
    expect(description).to include('Survey Solutions to Shared Drive: CSV, accent.',
                                   'Shared Drive to Analyst Machines: COPY, accent, dashed.')
    legend = REXML::XPath.match(xml, "//*[@data-sgr-legend-kind]").map { |item| item.attributes['data-sgr-legend-kind'] }
    expect(legend).to eq(%w[accent dashed pain_point external])
  end

  it 'replaces generated accessibility text with a supplied description' do
    graph = reference_landscape(description: 'Author summary: partners & internal systems.')
    xml = REXML::Document.new(graph.to_svg)

    expect(REXML::XPath.first(xml, "//*[local-name()='desc']").text).to eq(
      'Author summary: partners & internal systems.'
    )
  end

  it 'retains complete generated accessibility semantics when no description is supplied' do
    xml = REXML::Document.new(reference_landscape.to_svg)

    expect(REXML::XPath.first(xml, "//*[local-name()='desc']").text).to eq(
      'IT current-state. COLLECTION contains Survey Solutions: CAPI · PostgreSQL; Civil Registry, external: External · CRVS data. ' \
      'PROCESSING contains Shared Drive, pain point: No version control; Analyst Machines: SPSS · SAS · Stata · Excel. ' \
      'DISSEMINATION contains Legacy Portal, pain point: Manual bottleneck; NatStat Website: Public · static pages. ' \
      'Hand-offs: Survey Solutions to Shared Drive: CSV, accent. Civil Registry to Shared Drive: EXCEL, accent, dashed. ' \
      'Shared Drive to Analyst Machines: COPY, accent, dashed. Analyst Machines to Legacy Portal: EXCEL, accent. ' \
      'Legacy Portal to NatStat Website: WEB, accent. Cross-cutting service: Identity Manager: Active Directory · LDAP · SSO.'
    )
  end

  it 'matches the dashed legend swatch to the rendered hand-off pattern' do
    xml = REXML::Document.new(reference_landscape.to_svg)
    swatch = REXML::XPath.first(xml, "//*[@data-sgr-legend-kind='dashed']/*[local-name()='line']")
    handoff = REXML::XPath.first(xml, "//*[@data-sgr-handoff='registry-drive']")

    expect(swatch.attributes['stroke-dasharray']).to eq('4 3')
    expect(swatch.attributes['stroke-dasharray']).to eq(handoff.attributes['stroke-dasharray'])
  end

  it 'rejects unknown JSON fields, cross-type fields and non-boolean dashed values' do
    base = {
      type: 'it_state', phases: [
        { id: 'a', systems: [{ id: 'x' }] }, { id: 'b', systems: [{ id: 'y' }] }
      ], handoffs: [{ from: 'x', to: 'y', label: 'CSV' }]
    }
    expect { SlimGraphR::Document.from_json(JSON.generate(base.merge(nodes: []))) }.to raise_error(SlimGraphR::Error, /cross-type.*nodes/i)
    expect { SlimGraphR::Document.from_json(JSON.generate(base.merge(legend: []))) }.to raise_error(SlimGraphR::Error, /Unknown document fields: legend/)
    expect do
      SlimGraphR::Document.from_json(JSON.generate(base.merge(handoffs: [{ from: 'x', to: 'y', label: 'CSV', dashed: 'yes' }])))
    end.to raise_error(SlimGraphR::Error, /dashed must be true or false/)
    expect do
      invalid = Marshal.load(Marshal.dump(base))
      invalid[:phases][0][:systems][0][:version] = '1.0'
      SlimGraphR::Document.from_json(JSON.generate(invalid))
    end.to raise_error(SlimGraphR::Error, /Unknown systems fields: version/)
  end

  it 'distinguishes omitted JSON defaults from explicit nulls at every nested level' do
    base = {
      type: 'it_state', phases: [
        { id: 'a', systems: [{ id: 'x' }] }, { id: 'b', systems: [{ id: 'y' }] }
      ], handoffs: [{ from: 'x', to: 'y', label: 'CSV' }]
    }
    graph = SlimGraphR::Document.from_json(JSON.generate(base))
    expect([graph.nodes.first.kind, graph.edges.first.kind, graph.edges.first.dashed, graph.direction]).to eq([:standard, :neutral, false, :right])
    invalid = [
      base.merge(direction: nil),
      base.merge(phases: [{ id: 'a', label: nil, systems: [{ id: 'x' }] }, { id: 'b', systems: [{ id: 'y' }] }]),
      base.merge(phases: [{ id: 'a', systems: [{ id: 'x', state: nil }] }, { id: 'b', systems: [{ id: 'y' }] }]),
      base.merge(handoffs: [{ from: 'x', to: 'y', label: 'CSV', style: nil }]),
      base.merge(handoffs: [{ from: 'x', to: 'y', label: 'CSV', dashed: nil }]),
      base.merge(crosscuts: [{ id: 'identity', detail: nil }])
    ]
    invalid.each { |data| expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error) }
  end
end
