require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'Dependency diagrams' do
  def reference_graph
    SlimGraphR.diagram(:dependency, title: 'Runtime dependencies') do
      %i[app core plugins adapter hook].each { |id| dependency id }
      external_dependency :rack, 'Rack', version: '3.2.1', registry: 'RubyGems'

      depends_on :app, :core
      depends_on :app, :plugins
      depends_on :core, :adapter
      depends_on :plugins, :adapter
      depends_on :plugins, :hook
      depends_on :adapter, :rack
      depends_on :hook, :app, cycle: true
    end
  end

  it 'keeps the standalone Ruby and JSON examples equivalent' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = eval(File.read(File.join(root, 'dependency.rb')), binding, File.join(root, 'dependency.rb'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'dependency.json')))
    expect(json.to_svg(id: 'dependency-parity')).to eq(ruby.to_svg(id: 'dependency-parity'))
  end

  it 'models dependent-to-dependency direction, external metadata and explicit cycle intent' do
    graph = reference_graph
    expect(graph.direction).to eq(:down)
    expect([graph.edges.first.from, graph.edges.first.to, graph.edges.first.cycle]).to eq(['app', 'core', false])
    expect([graph.edges.last.from, graph.edges.last.to, graph.edges.last.cycle]).to eq(['hook', 'app', true])
    rack = graph.nodes.find { |node| node.id == 'rack' }
    expect([rack.kind, rack.version, rack.registry]).to eq([:external, '3.2.1', 'RubyGems'])
  end

  it 'lays out a shared diamond, external package and cycle in four ranked rows with honest fan-in' do
    scene = reference_graph.layout
    expect(scene.boxes.map(&:width).uniq).to eq([160])
    expect(scene.boxes.map(&:height).uniq).to eq([56])
    expect(scene.boxes.map(&:y).uniq.sort.each_cons(2).map { |a, b| b - a }).to eq([120, 120, 120])
    badges = scene.boxes.to_h { |box| [box.node.id, box.badges.first] }
    expected = reference_graph.nodes.to_h do |node|
      [node.id, "#{reference_graph.edges.count { |edge| edge.to == node.id }} in"]
    end
    expect(badges).to eq(expected)
    scene.boxes.each do |box|
      expect(box.badges).to contain_exactly(match(/\A\d+ in\z/))
      expect(box.metadata).to be_empty unless box.node.kind == :external
    end
    scene.routes.reject { |route| route.edge.cycle }.each do |route|
      source = scene.boxes.find { |box| box.node.id == route.edge.from }
      target = scene.boxes.find { |box| box.node.id == route.edge.to }
      expect(route.points.first[1]).to eq(source.bottom)
      expect(route.points.last[1]).to eq(target.y)
      expect(source.y).to be < target.y
      expect(route.points.each_cons(2).map { |a, b| b[1] - a[1] }).to all(be >= 0)
    end
  end

  it 'keeps every connector outside non-endpoint boxes and fans shared ports by at least twelve pixels' do
    scene = reference_graph.layout
    scene.routes.each do |route|
      route.points.each_cons(2) do |a, b|
        scene.boxes.reject { |box| [route.edge.from, route.edge.to].include?(box.node.id) }.each do |box|
          expect(SlimGraphR::Layout::Geometry.blocked?(a, b, box.rect)).to be(false), "#{route.edge.from}->#{route.edge.to} crosses #{box.node.id}"
        end
      end
      next unless route.label_box
      scene.boxes.each { |box| expect(SlimGraphR::Layout::Geometry.overlaps?(route.label_box[:rect], box.rect)).to be(false) }
    end
    segments = scene.routes.flat_map { |route| route.points.each_cons(2).to_a }
    segments.combination(2) do |(a, b), (c, d)|
      expect(SlimGraphR::Layout::Geometry.parallel_conflict?(a, b, c, d)).to be(false), "shared corridor: #{a}-#{b} and #{c}-#{d}"
    end

    ordinary = scene.routes
    attachments = ordinary.group_by { |route| route.edge.to }.values.flat_map do |routes|
      routes.map { |route| route.points.last[0] }.sort.each_cons(2).map { |a, b| b - a }
    end + ordinary.group_by { |route| route.edge.from }.values.flat_map do |routes|
      routes.map { |route| route.points.first[0] }.sort.each_cons(2).map { |a, b| b - a }
    end
    expect(attachments).to all(be >= 12)

    cycle_route = scene.routes.find { |route| route.edge.cycle }
    expect(cycle_route.points.any? { |point| point[0] > scene.boxes.map(&:right).max }).to be(true)
    expect(cycle_route.points.each_cons(2).any? { |a, b| a[0] == b[0] && b[1] < a[1] }).to be(true)
    expect(cycle_route.label_box).to include(cycle: true, lines: ['CYCLE'])
  end

  it 'clears same-rank siblings when a cycle leaves its source' do
    graph = SlimGraphR.diagram(:dependency) do
      %i[t a z].each { |id| dependency id }
      depends_on :t, :a
      depends_on :t, :z
      depends_on :a, :t, cycle: true
    end
    scene = graph.layout
    cycle = scene.routes.find { |route| route.edge.cycle }
    sibling = scene.boxes.find { |box| box.node.id == 'z' }
    cycle.points.each_cons(2) do |from, to|
      expect(SlimGraphR::Layout::Geometry.blocked?(from, to, sibling.rect)).to be(false)
    end
  end

  it 'places the cycle label eight pixels clear of its actual horizontal stroke' do
    scene = reference_graph.layout
    cycle = scene.routes.find { |route| route.edge.cycle }
    left, top, right, bottom = cycle.label_box.fetch(:rect)
    horizontal = cycle.points.each_cons(2).select do |a, b|
      a[1] == b[1] && [a[0], b[0]].min < right && [a[0], b[0]].max > left
    end
    distances = horizontal.map { |a, _b| [top - a[1], a[1] - bottom].max }
    expect(distances.min).to be_between(6, 10)
    scene.routes.each do |route|
      route.points.each_cons(2) do |a, b|
        if a[0] == b[0]
          intersects = a[0].between?(left, right) && [a[1], b[1]].min <= bottom && [a[1], b[1]].max >= top
        else
          intersects = a[1].between?(top, bottom) && [a[0], b[0]].min <= right && [a[0], b[0]].max >= left
        end
        expect(intersects).to be(false), "label intersects #{route.edge.from}->#{route.edge.to}"
      end
    end
  end

  it 'allocates at least twelve pixels between ordinary and cycle source attachments' do
    graph = SlimGraphR.diagram(:dependency) do
      %i[t a b c d e].each { |id| dependency id }
      depends_on :t, :a
      %i[b c d e].each { |id| depends_on :a, id }
      depends_on :a, :t, cycle: true
    end
    scene = graph.layout
    starts = scene.routes.select { |route| route.edge.from == 'a' }.map { |route| route.points.first }
    expect(starts.size).to eq(5)
    expect(starts.map(&:last).uniq).to eq([scene.boxes.find { |box| box.node.id == 'a' }.bottom])
    expect(starts.map(&:first).sort.each_cons(2).map { |a, b| b - a }).to all(be >= 12)
  end

  it 'never sends an ordinary edge upward to escape a crowded rank' do
    graph = SlimGraphR.diagram(:dependency) do
      %i[app cli core plugins adapter cycle_hook logger].each { |id| dependency id }
      external_dependency :rack, 'Rack', version: '3.2.1', registry: 'RubyGems'
      [[:app, :core], [:app, :plugins], [:cli, :core], [:core, :adapter],
       [:plugins, :adapter], [:plugins, :cycle_hook], [:adapter, :rack], [:core, :logger]].each do |from, to|
        depends_on from, to
      end
      depends_on :cycle_hook, :app, cycle: true
    end
    begin
      graph.layout.routes.reject { |route| route.edge.cycle }.each do |route|
        expect(route.points.each_cons(2).map { |a, b| b[1] - a[1] }).to all(be >= 0)
      end
    rescue SlimGraphR::LayoutError => error
      expect(error.message).to match(/Could not route dependency .*Split/)
    end
  end

  it 'renders an independent crossing with a hop or rejects the dense route clearly' do
    graph = SlimGraphR.diagram(:dependency) do
      %i[a b c d].each { |id| dependency id }
      depends_on :a, :c
      depends_on :a, :d
      depends_on :b, :c
      depends_on :b, :d
    end
    begin
      svg = graph.to_svg(id: 'crossed')
      expect(svg.scan(/data-sgr-hops="(\d+)"/).flatten.map(&:to_i).sum).to eq(1)
    rescue SlimGraphR::LayoutError => error
      expect(error.message).to match(/Could not route dependency/)
    end
  end

  it 'renders only the authored cycle edge and label in accent with accessible dependency wording' do
    svg = reference_graph.to_svg(id: 'dependency-example')
    expect(svg).to include('data-sgr-dependency="internal"', 'data-sgr-dependency="external"')
    expect(svg.scan('data-sgr-cycle="true"').size).to eq(2)
    expect(svg).to include('stroke-dasharray="5 4"', 'marker-end="url(#dependency-example-arrow-accent)"', '3.2.1 · RubyGems')
    expect(svg).to include('App depends on Core', 'Hook depends on App (cycle)')
  end

  it 'renders an internal leaf with its actual shared fan-in count' do
    graph = SlimGraphR.diagram(:dependency) do
      %i[app core plugins shared].each { |id| dependency id }
      depends_on :app, :core
      depends_on :app, :plugins
      depends_on :core, :shared
      depends_on :plugins, :shared
    end
    svg = graph.to_svg(id: 'shared-leaf')
    expect(svg).to include('data-sgr-dependency="leaf" data-sgr-dependency-id="shared"')
    expect(graph.layout.boxes.find { |box| box.node.id == 'shared' }.badges).to eq(['2 in'])
    expect(graph.layout.boxes.find { |box| box.node.id == 'app' }.badges).to eq(['0 in'])
  end

  it 'rejects generic graph vocabulary, invalid relationships and tree-shaped data clearly' do
    expect { SlimGraphR.diagram(:dependency) { node :a } }.to raise_error(SlimGraphR::Error, /use dependency/)
    expect { SlimGraphR.diagram(:dependency) { dependency :a; dependency :b; edge :a, :b } }.to raise_error(SlimGraphR::Error, /use depends_on/)
    expect { SlimGraphR.diagram(:dependency) { dependency :a; dependency :b; depends_on :a, :a } }.to raise_error(SlimGraphR::Error, /itself/)
    expect do
      SlimGraphR.diagram(:dependency) { dependency :a; dependency :b; depends_on :a, :b; depends_on :a, :b }
    end.to raise_error(SlimGraphR::Error, /Duplicate dependency/)
    expect do
      SlimGraphR.diagram(:dependency) { dependency :a; dependency :b; dependency :c; depends_on :a, :b; depends_on :b, :c }
    end.to raise_error(SlimGraphR::Error, /tree-shaped.*tree.*root.*child/i)
  end

  it 'requires a marked edge to close exactly one real cycle and leaves a DAG when removed' do
    expect do
      SlimGraphR.diagram(:dependency) do
        %i[a b c].each { |id| dependency id }
        depends_on :a, :b
        depends_on :c, :a, cycle: true
      end
    end.to raise_error(SlimGraphR::Error, /does not close a path/)

    expect do
      SlimGraphR.diagram(:dependency) do
        %i[a b c].each { |id| dependency id }
        depends_on :a, :b
        depends_on :b, :a
        depends_on :a, :c, cycle: true
      end
    end.to raise_error(SlimGraphR::Error, /remaining relationships.*acyclic/i)

    expect do
      SlimGraphR.diagram(:dependency) do
        %i[a b c].each { |id| dependency id }
        depends_on :a, :b
        depends_on :b, :a, cycle: true
        depends_on :c, :a, cycle: true
      end
    end.to raise_error(SlimGraphR::Error, /one cycle/i)
  end

  it 'enforces external metadata, fixed-box text fit and dependency budgets' do
    expect { SlimGraphR.diagram(:dependency) { external_dependency :rack, version: '', registry: 'RubyGems' } }.to raise_error(SlimGraphR::Error, /version.*blank/i)
    expect { SlimGraphR.diagram(:dependency) { external_dependency :rack, version: '3.2.1', registry: nil } }.to raise_error(SlimGraphR::Error, /registry/i)
    expect do
      SlimGraphR.diagram(:dependency) { dependency :this_name_cannot_fit_inside_the_fixed_dependency_box; dependency :a; depends_on :a, :this_name_cannot_fit_inside_the_fixed_dependency_box; dependency :b; depends_on :b, :this_name_cannot_fit_inside_the_fixed_dependency_box }
    end.to raise_error(SlimGraphR::Error, /160px dependency box/)
    expect do
      SlimGraphR.diagram(:dependency) do
        10.times { |i| dependency "n#{i}" }
        9.times { |i| depends_on "n#{i}", 'n9' }
      end
    end.to raise_error(SlimGraphR::Error, /nine nodes/)
  end

  it 'parses strict JSON into the same Ruby model and rejects cross-type fields and non-booleans' do
    data = {
      type: 'dependency', title: 'Small graph',
      nodes: [{ id: 'app' }, { id: 'cli' }, { id: 'core' }, { id: 'rack', kind: 'external', version: '3.2.1', registry: 'RubyGems' }],
      edges: [{ from: 'app', to: 'core' }, { from: 'cli', to: 'core' }, { from: 'core', to: 'rack' }]
    }
    graph = SlimGraphR::Document.from_json(JSON.generate(data))
    expect(graph.nodes.last.version).to eq('3.2.1')
    expect(graph.to_svg(id: 'json-dependency')).to include('2 in', '3.2.1 · RubyGems')
    expect { SlimGraphR::Document.from_json(JSON.generate(data.merge(edges: [{ from: 'app', to: 'core', cycle: 'yes' }]))) }.to raise_error(SlimGraphR::Error, /cycle must be true or false/)
    expect { SlimGraphR::Document.from_json(JSON.generate(data.merge(nodes: [{ id: 'a', detail: 'wrong' }]))) }.to raise_error(SlimGraphR::Error, /Unknown nodes fields: detail/)
  end

  it 'keeps dependency IDs, metadata, fields and references strict in Ruby and JSON' do
    expect { SlimGraphR.diagram(:dependency) { dependency ''; dependency :a; depends_on :a, '' } }.to raise_error(SlimGraphR::Error, /IDs must not be blank/)
    expect { SlimGraphR.diagram(:dependency) { dependency :a; dependency :a } }.to raise_error(SlimGraphR::Error, /unique/)

    base = {
      type: 'dependency',
      nodes: [{ id: 'a' }, { id: 'b' }, { id: 'shared' }],
      edges: [{ from: 'a', to: 'shared' }, { from: 'b', to: 'shared' }]
    }
    invalid = [
      base.merge(nodes: [{ id: nil }]),
      base.merge(edges: [{ from: nil, to: 'shared' }]),
      base.merge(nodes: [{ id: 'a', kind: 'store' }]),
      base.merge(nodes: [{ id: 'rack', kind: 'external', registry: 'RubyGems' }]),
      base.merge(nodes: [{ id: 'a', version: '1.0' }]),
      base.merge(edges: [{ from: 'a', to: 'shared', label: 'wrong' }]),
      base.merge(groups: [])
    ]
    invalid.each { |value| expect { SlimGraphR::Document.from_json(JSON.generate(value)) }.to raise_error(SlimGraphR::Error) }
  end
end
