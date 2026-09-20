require 'spec_helper'
RSpec.describe 'Layout geometry' do
  def assert_geometry(scene)
    scene.boxes.combination(2) { |a, b| expect(SlimGraphR::Layout::Geometry.overlaps?(a.rect, b.rect)).to be(false) }
    scene.routes.each do |route|
      route.points.each_cons(2) do |a, b|
        expect(a[0] == b[0] || a[1] == b[1]).to be(true)
        scene.boxes.each do |box|
          expect(SlimGraphR::Layout::Geometry.blocked?(a, b, box.rect)).to be(false), "#{route.edge.from}->#{route.edge.to} crosses #{box.node.id}: #{a}, #{b}"
        end
      end
      if route.label_box
        scene.boxes.each { |box| expect(SlimGraphR::Layout::Geometry.overlaps?(route.label_box[:rect], box.rect)).to be(false) }
      end
    end
  end

  %i[right down].each do |direction|
    it "routes branches, merges, skip connections, cycles and disconnected nodes #{direction}" do
      graph = SlimGraphR.diagram(:flowchart, direction: direction) do
        %i[start check approve reject save audit isolated].each { |id| node id }
        flow :start, :check, :approve, :save
        edge :check, :reject
        edge :reject, :save
        edge :save, :check, dashed: true
        edge :start, :audit
        edge :audit, :save
      end
      assert_geometry(graph.layout)
    end
  end

  it 'routes repeated edges from distinct ports and self-loops outside the node' do
    graph = SlimGraphR.diagram do
      node :a
      node :b
      edge :a, :b
      edge :a, :b
      edge :a, :a
    end
    scene = graph.layout
    expect(scene.routes[0].points.first).not_to eq(scene.routes[1].points.first)
    assert_geometry(scene)
  end

  it 'keeps labeled branches legible' do
    graph = SlimGraphR.diagram(:flowchart) do
      node :request
      decision :check, 'Ready to publish?', emphasis: true
      node :publish
      node :revise
      edge :request, :check
      edge :check, :publish, 'Approved'
      edge :check, :revise, 'Needs changes'
    end
    scene = graph.layout
    assert_geometry(scene)
    scene.routes.each do |route|
      next unless route.label_box
      scene.routes.reject { |other| other.equal?(route) }.each do |other|
        other.points.each_cons(2) { |a, b| expect(SlimGraphR::Layout::Geometry.blocked?(a, b, route.label_box[:rect])).to be(false) }
      end
    end
  end

  it 'bounds groups around their members without enclosing unrelated nodes' do
    graph = SlimGraphR.diagram do
      group(:frontend, 'Frontend') { node :web; node :mobile }
      group(:backend, 'Backend') { node :api; store :db }
      edge :web, :api
      edge :mobile, :api
      edge :api, :db
    end
    scene = graph.layout
    assert_geometry(scene)
    scene.zones.each_with_index do |zone, i|
      scene.boxes.reject { |b| b.node.group == graph.groups[i].id }.each do |box|
        expect(SlimGraphR::Layout::Geometry.overlaps?(zone[:rect], box.rect)).to be(false)
      end
    end
  end

  it 'supports forests but rejects cyclic or multiple-parent org charts' do
    graph = SlimGraphR.diagram(:org_chart) { node :a; node :b; node :c; edge :a, :b }
    assert_geometry(graph.layout)
    expect { SlimGraphR.diagram(:org_chart) { node :a; node :b; flow :a, :b, :a }.layout }.to raise_error(SlimGraphR::Error, /cycle/)
    expect { SlimGraphR.diagram(:org_chart) { node :a; node :b; node :c; edge :a, :c; edge :b, :c } }.to raise_error(SlimGraphR::Error, /one parent/)
  end

  it 'lays out sequence self-messages and long labels in increasing time order' do
    graph = SlimGraphR.diagram(:sequence) do
      participant :client
      participant :server
      message :client, :server, 'A longer request that needs to wrap onto more than one line'
      message :server, :server, 'Check cached result'
      message :server, :client, 'Ready', dashed: true
    end
    scene = graph.layout
    expect(scene.routes.map { |r| r.points.first[1] }).to eq(scene.routes.map { |r| r.points.first[1] }.sort)
    expect(scene.routes[1].points.size).to eq(4)
    expect(scene.routes.first.label_box[:lines].size).to be > 1
  end

  it 'preserves author order and wraps timeline dates and detail' do
    graph = SlimGraphR.diagram(:timeline) do
      event 'This week', 'Define the model', detail: 'Capture the content and relationships.'
      event 'Next', 'Ship the renderer', emphasis: true
    end
    expect(graph.layout.events.map { |e| e[:event].date }).to eq(['This week', 'Next'])
    expect { REXML::Document.new(graph.to_svg) }.not_to raise_error
  end

  it 'uses honest elapsed spacing for parseable dates and exposes axis ticks' do
    graph = SlimGraphR.diagram(:timeline, title: 'Release history', scale: :date) do
      event '2026-01-01', 'First cut'
      event '2026-01-11', 'Second cut', emphasis: true
      event '2026-02-10', 'Stable release'
    end
    scene = graph.layout
    expect(scene.axis[:mode]).to eq(:date)
    expect(scene.axis[:ticks].map { |tick| tick[:label] }).to eq(%w[2026-01-01 2026-01-15 2026-01-29 2026-02-10])
    xs = scene.events.map { |event| event[:x] }
    expect(xs).to eq(xs.sort)
    expect(xs[1] - xs[0]).to be < xs[2] - xs[1]
    expect(graph.to_svg).to include('2026-01-01', '2026-02-10')
  end

  it 'keeps non-date milestones in an explicit ordered mode' do
    graph = SlimGraphR.diagram(:timeline, scale: :ordered) do
      event 'Now', 'Describe the intent'
      event 'Next', 'Render the picture'
    end
    expect(graph.layout.axis[:mode]).to eq(:ordered)
    expect { SlimGraphR.diagram(:timeline, scale: :date) { event 'Now', 'Not a date' }.layout }.to raise_error(SlimGraphR::Error, /requires every event date/)
  end

  it 'auto selects dates only when every event parses' do
    expect(SlimGraphR.diagram(:timeline) { event '2026-01-01', 'A'; event '2026-01-02', 'B' }.layout.axis[:mode]).to eq(:date)
    expect(SlimGraphR.diagram(:timeline) { event 'Today', 'A'; event 'Tomorrow', 'B' }.layout.axis[:mode]).to eq(:ordered)
  end
end
