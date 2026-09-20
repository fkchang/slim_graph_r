require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'Flowchart semantics and connector conformance' do
  let(:graph) do
    SlimGraphR.diagram :flowchart, title: 'Complete request' do
      start :request, 'New request'
      decision :valid, 'Is the request complete?', emphasis: true
      step :process
      step :repair
      merge :joined
      finish :done
      flow :request, :valid
      edge :valid, :process, 'Yes'
      edge :valid, :repair, 'No'
      flow :process, :joined, :done
      edge :repair, :joined
    end
  end

  it 'renders distinct terminators, a real diamond, and a small merge point' do
    doc = REXML::Document.new(graph.to_svg)
    expect(REXML::XPath.match(doc, '//*[@data-sgr-shape="start"]').size).to eq(1)
    expect(REXML::XPath.match(doc, '//*[@data-sgr-shape="finish"]').size).to eq(1)
    expect(REXML::XPath.first(doc, '//*[@data-sgr-shape="start"]')['rx']).to eq('20')
    diamond = REXML::XPath.first(doc, '//*[@data-sgr-shape="decision"]')
    expect(diamond.name).to eq('polygon')
    expect(diamond['points'].split.size).to eq(4)
    junction = REXML::XPath.first(doc, '//*[@data-sgr-shape="merge"]')
    expect(junction.name).to eq('circle')
    expect(junction['r']).to eq('4')
    expect(graph.to_svg).to include('Merge: Joined', 'Start: New request', 'Decision: Is the request complete?')
  end

  it 'attaches arrows to shape boundaries and keeps merge ports distinct' do
    scene = graph.layout
    diamond = scene.boxes.find { |b| b.shape == :diamond }
    yes = scene.routes.find { |r| r.edge.label == 'Yes' }
    no = scene.routes.find { |r| r.edge.label == 'No' }
    expect(yes.points.first).to eq(diamond.boundary(:right))
    expect(no.points.first).to eq(diamond.boundary(:bottom))
    expect(scene.boxes.find { |b| b.node.id == 'process' }.center[1]).to eq(diamond.center[1])
    expect(scene.boxes.find { |b| b.node.id == 'repair' }.center[0]).to eq(diamond.center[0])
    merge = scene.boxes.find { |b| b.shape == :merge }
    inputs = scene.routes.select { |r| r.edge.to == 'joined' }.map { |r| r.points.last }
    expect(inputs.uniq.size).to eq(2)
    inputs.each { |x, y| expect((x - merge.center[0])**2 + (y - merge.center[1])**2).to eq(16) }
    scene.routes.select { |r| r.edge.to == 'joined' }.each do |route|
      source = scene.boxes.find { |b| b.node.id == route.edge.from }
      side = source.center[0] < merge.center[0] ? :left : :right
      expect(route.points.last).to eq(merge.boundary(side))
    end
  end

  it 'sizes long decision labels and detail to fit safely inside the diamond' do
    model = SlimGraphR.diagram(:flowchart) do
      decision :review, 'Can this request be fulfilled without another round of clarification?', detail: 'Check the available information before making a choice.'
      finish :yes
      finish :no
      edge :review, :yes, 'Yes'
      edge :review, :no, 'No'
    end
    box = model.layout.boxes.find { |b| b.shape == :diamond }
    expect(box.width).to eq(box.height * 2)
    content_height = box.lines.size * 20 + box.details.size * 16 + 8
    expect(content_height).to be <= box.height / 2 - 24
    box.lines.each { |line| expect(SlimGraphR::Text.width(line)).to be <= box.width / 2 - 32 }
    box.details.each { |line| expect(SlimGraphR::Text.width(line, 12)).to be <= box.width / 2 - 32 }
  end

  it 'keeps every label eight pixels clear of every connector, including its own' do
    scene = graph.layout
    scene.routes.each do |route|
      next unless route.label_box
      x, y, r, b = route.label_box[:rect]
      padded = [x - 8, y - 8, r + 8, b + 8]
      scene.routes.each do |other|
        other.points.each_cons(2) do |a, z|
          expect(SlimGraphR::Layout::Geometry.blocked?(a, z, padded)).to be(false)
        end
      end
    end
  end

  it 'separates parallel strokes, keeps routes inside the canvas, and avoids unrelated nodes' do
    scene = graph.layout
    scene.routes.combination(2) do |first, second|
      first.points.each_cons(2) do |a, b|
        second.points.each_cons(2) { |c, d| expect(SlimGraphR::Layout::Geometry.parallel_conflict?(a, b, c, d)).to be(false) }
      end
    end
    scene.routes.each do |route|
      route.points.each do |x, y|
        expect(x).to be_between(0, scene.width)
        expect(y).to be_between(0, scene.height)
      end
      scene.boxes.reject { |box| [route.edge.from, route.edge.to].include?(box.node.id) }.each do |box|
        route.points.each_cons(2) { |a, b| expect(SlimGraphR::Layout::Geometry.blocked?(a, b, box.rect)).to be(false) }
      end
    end
  end

  it 'routes three guarded branches and a three-input junction in either orientation' do
    %i[down right].each do |direction|
      model = SlimGraphR.diagram(:flowchart, direction: direction) do
        start :request
        decision :classify
        %i[low middle high].each { |id| step id }
        merge :joined
        finish :done
        flow :request, :classify
        %i[low middle high].each { |id| edge :classify, id, id.to_s; edge id, :joined }
        flow :joined, :done
      end
      expect { REXML::Document.new(model.to_svg) }.not_to raise_error
      endpoints = model.layout.routes.select { |r| r.edge.to == 'joined' }.map { |r| r.points.last }
      expect(endpoints.uniq.size).to eq(3)
    end
  end

  it 'reserves future ports and hop clearance in an intentionally crossed graph' do
    model = SlimGraphR.diagram(:flowchart) do
      %i[a b c d].each { |id| step id }
      edge :a, :d, 'First'
      edge :b, :c, 'Second'
    end
    scene = model.layout
    first, second = scene.routes
    crosses = first.points.each_cons(2).flat_map do |a, b|
      second.points.each_cons(2).filter_map { |c, d| SlimGraphR::Layout::Geometry.crossing(a, b, c, d) }
    end
    expect(crosses).not_to be_empty
    expect(model.to_svg).to include('data-sgr-hops="1"')
    crosses.each do |x, y|
      scene.routes.each do |route|
        expect(SlimGraphR::Layout::Geometry.overlaps?(route.label_box[:rect], [x - 16, y - 16, x + 16, y + 16])).to be(false)
      end
    end
    # Every meeting of independent paths must be an interior crossing, never a bend/port that looks like a junction.
    first.points.each do |point|
      second.points.each_cons(2) do |a, b|
        on_line = (a[0] == b[0] && point[0] == a[0] && point[1].between?(*[a[1], b[1]].sort)) ||
                  (a[1] == b[1] && point[1] == a[1] && point[0].between?(*[a[0], b[0]].sort))
        expect(on_line).to be(false)
      end
    end
  end

  it 'refuses to claim a hop when a crossing is inside a rounded corner' do
    model = SlimGraphR.diagram { node :a }
    renderer = SlimGraphR::SVG.new(model, model.layout)
    expect do
      renderer.send(:rounded_path, [[20, 100], [100, 100], [100, 180]], [[96, 100]])
    end.to raise_error(SlimGraphR::LayoutError, /rounded bend/)
  end

  it 'rejects unlabeled decisions, excess exits, and misleading start/end/merge topology' do
    expect { SlimGraphR.diagram(:flowchart) { decision :a; step :b; flow :a, :b } }.to raise_error(SlimGraphR::Error, /Label every exit/)
    expect do
      SlimGraphR.diagram(:flowchart) { decision :a; 4.times { |i| step i; edge :a, i, "Choice #{i}" } }
    end.to raise_error(SlimGraphR::Error, /three exits/)
    expect { SlimGraphR.diagram(:flowchart) { start :a; step :b; edge :b, :a } }.to raise_error(SlimGraphR::Error, /incoming/)
    expect { SlimGraphR.diagram(:flowchart) { finish :a; step :b; edge :a, :b } }.to raise_error(SlimGraphR::Error, /outgoing/)
    expect { SlimGraphR.diagram(:flowchart) { merge :a } }.to raise_error(SlimGraphR::Error, /two or three inputs/)
    expect { SlimGraphR.diagram(:architecture) { start :a } }.to raise_error(SlimGraphR::Error, /flowchart/)
  end

  it 'accepts the same semantic node kinds through JSON' do
    input = { type: 'flowchart', nodes: [{ id: 'start', kind: 'start' }, { id: 'done', kind: 'finish' }], edges: [{ from: 'start', to: 'done' }] }
    expect(SlimGraphR::Document.from_json(JSON.generate(input)).to_svg).to include('data-sgr-shape="start"', 'data-sgr-shape="finish"')
  end

  it 'bridges a crossing on the later, dashed connector' do
    model = SlimGraphR.diagram { node :a; node :b; edge :a, :b }
    first = SlimGraphR::Layout::Route.new(edge: SlimGraphR::Edge.new(from: 'a', to: 'b'), points: [[20, 100], [180, 100]])
    second = SlimGraphR::Layout::Route.new(edge: SlimGraphR::Edge.new(from: 'a', to: 'b', dashed: true), points: [[100, 20], [100, 180]])
    scene = SlimGraphR::Layout::Scene.new(boxes: [], routes: [second, first], zones: [], lifelines: [], events: [], width: 200, height: 200)
    xml = REXML::Document.new(SlimGraphR::SVG.new(model, scene).render)
    paths = REXML::XPath.match(xml, '//*[@data-sgr-connector="true"]')
    expect(paths.map { |p| p['data-sgr-hops'] }).to eq(%w[0 1])
    expect(paths.last['d']).to include('A 8 8')
    expect(paths.last['stroke-dasharray']).to eq('4 4')
  end
end
