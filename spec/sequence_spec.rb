require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'Sequence control and message semantics' do
  def example(name)
    path = File.expand_path("../examples/standalone/#{name}.rb", __dir__)
    eval(File.read(path, encoding: 'UTF-8'), binding, path)
  end

  it 'keeps Ruby and nested JSON frame documents equivalent' do
    ruby = example('sequence_frames')
    json = SlimGraphR::Document.from_json(File.read(File.expand_path('../examples/standalone/sequence_frames.json', __dir__)))
    expect(ruby.to_svg(id: 'parity')).to eq(json.to_svg(id: 'parity'))
    expect(ruby.to_svg(id: 'repeat')).to eq(ruby.to_svg(id: 'repeat'))
    expect(ruby.sequence_items).to be_frozen
    activation = ruby.sequence_items.last
    expect(activation).to be_frozen
    expect(activation.items.first.regions.first.items).to be_frozen
  end

  it 'starts activation at the incoming call, ends after its reply, and anchors at the bar boundary' do
    graph = SlimGraphR.diagram(:sequence) do
      participant :client
      participant :api
      message :client, :api, 'Request'
      activate :api do
        reply :api, :client, label: 'Response'
      end
    end
    scene = graph.layout
    bar = scene.activations.first[:rect]
    incoming, reply = scene.routes
    expect(bar[2] - bar[0]).to eq(8)
    expect(bar[1]).to eq(incoming.points.last[1])
    expect(bar[3]).to be > reply.points.first[1]
    expect(incoming.points.last[0]).to eq(bar[0])
    expect(reply.points.first[0]).to eq(bar[0])
  end

  it 'keeps sibling activations disjoint and anchors only fresh incoming messages' do
    graph = SlimGraphR.diagram(:sequence) do
      participant :worker
      participant :client
      activate(:worker) { message :worker, :worker, 'First job' }
      activate(:worker) { message :worker, :worker, 'Second job' }
      message :client, :worker, 'Third job'
      activate(:worker) { reply :worker, :client, 'Done' }
    end
    scene = graph.layout
    bars = scene.activations
    expect(bars.map { |bar| bar[:depth] }).to eq([0, 0, 0])
    bars.each_cons(2) { |a, b| expect(a[:rect][3]).to be <= b[:rect][1] }
    incoming = scene.routes.find { |route| route.edge.label == 'Third job' }
    expect(bars.last[:rect][1]).to eq(incoming.points.last[1])
  end

  it 'keeps outer activation open across the whole alt frame and scopes inner activations to their branch' do
    scene = example('sequence_frames').layout
    outer = scene.activations.find { |bar| bar[:actor] == 'api' }
    inner = scene.activations.find { |bar| bar[:actor] == 'store' }
    expect(outer[:rect][1]).to eq(scene.routes.first.points.last[1])
    expect(outer[:rect][3]).to be > scene.routes.last.points.last[1]
    expect(inner[:rect][1]).to be > scene.fragments.first[:regions].last[:divider]
    expect(inner[:rect][3]).to be < outer[:rect][3]
  end

  it 'renders nested activation levels and distinct call, return, async and success markers' do
    graph = SlimGraphR.diagram(:sequence) do
      participant :client
      participant :service
      message :client, :service, 'Call'
      activate :service do
        message :service, :service, 'Delegate internally'
        activate :service do
          notify :service, :client, label: 'Notification'
        end
        message :service, :client, 'Success', kind: :success
      end
      reply :client, :service, 'Acknowledged'
    end
    bars = graph.layout.activations
    expect(bars.map { |bar| bar[:depth] }).to eq([0, 1])
    expect(bars[1][:rect][0] - bars[0][:rect][0]).to eq(4)
    xml = REXML::Document.new(graph.to_svg(id: 'kinds'))
    markers = REXML::XPath.match(xml, '//*[@data-sgr-message-kind]').to_h { |node| [node['data-sgr-message-kind'], node] }
    expect(markers.fetch('call')['marker-end']).to eq('url(#kinds-arrow)')
    expect(markers.fetch('return')['stroke-dasharray']).to eq('4 4')
    expect(markers.fetch('return')['marker-end']).to eq('url(#kinds-arrow)')
    expect(markers.fetch('async')['marker-end']).to eq('url(#kinds-arrow-open)')
    expect(markers.fetch('async')['stroke-dasharray']).to eq('4 4')
    expect(markers.fetch('success')['marker-end']).to eq('url(#kinds-arrow-accent)')
    expect(markers.fetch('success')['stroke-dasharray']).to be_nil
    expect(REXML::XPath.first(xml, '//*[@id="kinds-arrow-open"]/path')['fill']).to eq('none')
    expect(REXML::XPath.first(xml, '//*[@id="kinds-arrow"]/path')['fill']).not_to eq('none')
  end

  it 'preserves the old dashed syntax as a return and rejects contradictory message flags' do
    graph = SlimGraphR.diagram(:sequence) { participant :a; participant :b; message :a, :b, 'Reply', dashed: true }
    expect(graph.edges.first.kind).to eq(:return)
    expect do
      SlimGraphR.diagram(:sequence) { participant :a; participant :b; message :a, :b, kind: :async, dashed: false }
    end.to raise_error(SlimGraphR::Error, /dashed: true/)
    expect { SlimGraphR.diagram { node :a; node :b; reply :a, :b } }.to raise_error(SlimGraphR::Error, /sequence/)
  end

  it 'lays out guards, dividers and messages in separate vertical regions' do
    graph = example('sequence_frames')
    scene = graph.layout
    frame = scene.fragments.first
    expect(frame[:operator]).to eq(:alt)
    expect(frame[:actors].sort).to eq(%w[api client store])
    divider = frame[:regions].last[:divider]
    first_branch_reply = scene.routes.find { |r| r.edge.label == 'Cached document' }
    second_branch_start = scene.routes.find { |r| r.edge.label == 'Read document' }
    expect(divider - first_branch_reply.points.last[1]).to be >= 16
    expect(second_branch_start.points.first[1] - divider).to be >= 24
    scene.routes.drop(1).each do |route|
      route.points.each do |x, y|
        expect(x).to be_between(frame[:rect][0], frame[:rect][2])
        expect(y).to be_between(frame[:rect][1], frame[:rect][3])
      end
    end
    svg = graph.to_svg
    expect(svg).to include('data-sgr-frame="alt"', '[cached]', '[not cached]', 'Alternatives:', 'When not cached:')
  end

  it 'supports two separate opt/loop frames and leaves an uninvolved trailing actor outside opt' do
    graph = example('sequence_loop')
    scene = graph.layout
    expect(scene.fragments.map { |f| f[:operator] }).to eq(%i[loop opt])
    opt = scene.fragments.last
    metrics = scene.boxes.find { |box| box.node.id == 'metrics' }
    expect(opt[:rect][2]).to be < metrics.center[0]
    expect(scene.fragments.first[:rect][3]).to be < opt[:rect][1]
    expect(graph.to_svg).to include('Repeat:', 'Optional:')
  end

  it 'keeps long labels out of lifelines, self labels to the right, and all content inside the scene' do
    graph = SlimGraphR.diagram(:sequence) do
      participant :a
      participant :b
      participant :c
      message :a, :c, 'A long call across an uninvolved middle participant whose lifeline must stay visible'
      activate :c do
        message :c, :c, 'A long internal operation requiring several lines of explanation before returning'
      end
    end
    scene = graph.layout
    scene.routes.each do |route|
      box = route.label_box[:rect]
      scene.lifelines.each { |x, y1, y2| expect(SlimGraphR::Layout::Geometry.blocked?([x, y1], [x, y2], box)).to be(false) }
      expect(box[2]).to be < scene.width
      expect(box[3]).to be < scene.height
    end
    self_call = scene.routes.last
    expect(self_call.label_box[:rect][0] - self_call.points[1][0]).to be >= 8
  end

  it 'treats loop as a declaration, evaluates its body once, and escapes guards' do
    calls = 0
    graph = SlimGraphR.diagram(:sequence) do
      participant :worker
      loop '<script>alert(1)</script>' do
        calls += 1
        message :worker, :worker, 'Work'
      end
    end
    expect(calls).to eq(1)
    expect(graph.edges.size).to eq(1)
    expect(graph.to_svg).to include('&lt;script&gt;')
    expect(graph.to_svg).not_to include('<script>')
  end

  it 'rejects missing blocks, empty scopes, bad branches, nested frames and unknown activation actors' do
    expect { SlimGraphR.diagram(:sequence) { participant :a; activate :a } }.to raise_error(SlimGraphR::Error, /block/)
    expect { SlimGraphR.diagram(:sequence) { participant :a; activate(:a) {} } }.to raise_error(SlimGraphR::Error, /contain a message/)
    expect { SlimGraphR.diagram(:sequence) { participant :a; branch('x') {} } }.to raise_error(SlimGraphR::Error, /inside alt/)
    expect { SlimGraphR.diagram(:sequence) { participant :a; alt { message :a, :a } } }.to raise_error(SlimGraphR::Error, /branch blocks/)
    expect { SlimGraphR.diagram(:sequence) { participant :a; alt { branch('x') { message :a, :a } } } }.to raise_error(SlimGraphR::Error, /two branch/)
    expect { SlimGraphR.diagram(:sequence) { participant :a; opt('x') { loop('y') { message :a, :a } } } }.to raise_error(SlimGraphR::Error, /Nested sequence/)
    expect { SlimGraphR.diagram(:sequence) { participant :a; activate(:missing) { message :a, :a } } }.to raise_error(SlimGraphR::Error, /Unknown activation/)
  end

  it 'enforces bounded sequence complexity and frame participant adjacency' do
    expect { SlimGraphR.diagram(:sequence) { 6.times { |i| participant i } } }.to raise_error(SlimGraphR::Error, /five participants/)
    expect { SlimGraphR.diagram(:sequence) { participant :a; 13.times { message :a, :a } } }.to raise_error(SlimGraphR::Error, /twelve messages/)
    expect { SlimGraphR.diagram(:sequence) { participant :a; 3.times { opt('x') { message :a, :a } } } }.to raise_error(SlimGraphR::Error, /at most two/)
    graph = SlimGraphR.diagram(:sequence) { participant :a; participant :b; participant :c; opt('x') { message :a, :c } }
    expect { graph.layout }.to raise_error(SlimGraphR::LayoutError, /adjacent/)
  end

  it 'rejects ambiguous or malformed JSON sequence structure without silently dropping it' do
    base = { type: 'sequence', nodes: [{ id: 'a' }] }
    expect { SlimGraphR::Document.from_json(JSON.generate(base.merge(edges: [], steps: []))) }.to raise_error(SlimGraphR::Error, /either/)
    expect { SlimGraphR::Document.from_json(JSON.generate(base.merge(steps: [{ activate: 'a', steps: [], typo: true }]))) }.to raise_error(SlimGraphR::Error, /Unknown/)
    expect { SlimGraphR::Document.from_json(JSON.generate(base.merge(steps: [{ message: { from: 'a', to: 'a', kind: 'bogus' } }]))) }.to raise_error(SlimGraphR::Error, /Message kind/)
    expect { SlimGraphR::Document.from_json(JSON.generate(base.merge(type: 'architecture', steps: []))) }.to raise_error(SlimGraphR::Error, /Only a sequence/)
  end
end
