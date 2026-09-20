# frozen_string_literal: true
require 'spec_helper'
require 'json'
require 'cgi'
require 'slim_graph_r/document'

RSpec.describe 'bounded loop diagrams' do
  def loop_graph(count: 5, style: :editorial, theme: :light, description: nil)
    ids = %i[capture research decide act measure archive publish review].first(count)
    SlimGraphR.diagram(:loop, title: 'Learning loop · 学習', direction: :clockwise,
                      style: style, theme: theme, description: description) do
      hub :memory, 'Shared memory', sublabel: 'one record, every loop'
      ids.each_with_index { |id, index| station id, id.to_s.capitalize, sublabel: "phase #{index + 1}", focal: id == :decide }
      cycle(*ids)
      write_back ids.first, to: :memory, label: 'SIGNALS'
      write_back ids.drop(1), to: :memory
    end
  end

  it 'starts red with an explicit immutable dedicated model and authored cycle order' do
    graph = loop_graph
    expect(graph.loop_hub.to_h).to eq(id: 'memory', label: 'Shared memory', sublabel: 'one record, every loop')
    expect(graph.loop_cycle).to eq(%w[capture research decide act measure])
    expect(graph.loop_stations).to all(be_frozen)
    expect(graph.loop_write_backs).to all(be_frozen)
    expect([graph.loop_hub, graph.loop_stations, graph.loop_cycle, graph.loop_write_backs]).to all(be_frozen)
  end

  it 'keeps standalone Ruby and strict JSON byte-identical with a fixed ID' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = TOPLEVEL_BINDING.eval(File.read(File.join(root, 'loop.rb'), encoding: 'UTF-8'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'loop.json'), encoding: 'UTF-8'))
    expect(json.to_svg(id: 'loop-contract')).to eq(ruby.to_svg(id: 'loop-contract'))
  end

  it 'requires clockwise, one hub, five to eight stations, and one focal at most' do
    expect { SlimGraphR.diagram(:loop) {} }.to raise_error(SlimGraphR::Error, /direction.*clockwise/i)
    expect { SlimGraphR.diagram(:loop, direction: :counterclockwise) {} }.to raise_error(SlimGraphR::Error, /clockwise/i)
    expect do
      SlimGraphR.diagram(:loop, direction: :clockwise) { hub :a, 'A'; hub :b, 'B' }
    end.to raise_error(SlimGraphR::Error, /exactly one hub/i)
    expect do
      SlimGraphR.diagram(:loop, direction: :clockwise) do
        hub :h, 'H'; %i[a b c d].each { |id| station id, id.to_s }; cycle :a, :b, :c, :d
      end
    end.to raise_error(SlimGraphR::Error, /five to eight stations/i)
    expect do
      SlimGraphR.diagram(:loop, direction: :clockwise) do
        hub :h, 'H'; %i[a b c d e].each_with_index { |id, i| station id, id.to_s, focal: i < 2 }; cycle :a, :b, :c, :d, :e
        write_back %i[a b c d e], to: :h
      end
    end.to raise_error(SlimGraphR::Error, /at most one focal/i)
  end

  it 'requires the cycle to name every station exactly once and thereby declares closure' do
    expect do
      SlimGraphR.diagram(:loop, direction: :clockwise) do
        hub :h, 'H'; %i[a b c d e].each { |id| station id, id.to_s }; cycle :a, :b, :c, :d
        write_back %i[a b c d e], to: :h
      end
    end.to raise_error(SlimGraphR::Error, /cycle.*every station exactly once/i)
    expect do
      SlimGraphR.diagram(:loop, direction: :clockwise) do
        hub :h, 'H'; %i[a b c d e].each { |id| station id, id.to_s }; cycle :a, :b, :c, :d, :d
        write_back %i[a b c d e], to: :h
      end
    end.to raise_error(SlimGraphR::Error, /cycle.*every station exactly once/i)
    expect(loop_graph.layout.cycle_arcs.last.to_id).to eq('capture')
  end

  it 'requires exactly one explicitly declared write-back per station with hub destinations' do
    expect do
      SlimGraphR.diagram(:loop, direction: :clockwise) do
        hub :h, 'H'; %i[a b c d e].each { |id| station id, id.to_s }; cycle :a, :b, :c, :d, :e
        write_back %i[a b c d], to: :h
      end
    end.to raise_error(SlimGraphR::Error, /exactly one declared write-back per station/i)
    expect do
      SlimGraphR.diagram(:loop, direction: :clockwise) do
        hub :h, 'H'; %i[a b c d e].each { |id| station id, id.to_s }; cycle :a, :b, :c, :d, :e
        write_back %i[a b c d e], to: :h; write_back :a, to: :h
      end
    end.to raise_error(SlimGraphR::Error, /exactly one declared write-back per station/i)
    expect do
      SlimGraphR.diagram(:loop, direction: :clockwise) do
        hub :h, 'H'; %i[a b c d e].each { |id| station id, id.to_s }; cycle :a, :b, :c, :d, :e
        write_back %i[a b c d e], to: :elsewhere
      end
    end.to raise_error(SlimGraphR::Error, /write-back destination.*hub/i)
  end

  it 'renders measured cards, equal-angle order, same-radius clockwise arcs, closure, and edge-clipped spokes' do
    [loop_graph(count: 5).layout, loop_graph(count: 8).layout].each do |scene|
      expect(scene.station_boxes).to all(satisfy { |box| box.width == 160 && box.height == 64 })
      expect([scene.hub_box.width, scene.hub_box.height]).to eq([200, 104])
      expect(scene.station_boxes.first.angle).to eq(-90.0)
      gaps = scene.station_boxes.each_cons(2).map { |a, b| (b.angle - a.angle).round(6) }
      expect(gaps.uniq.size).to eq(1)
      expect(scene.cycle_arcs.map(&:radius).uniq).to eq([scene.radius])
      expect(scene.cycle_arcs).to all(satisfy { |arc| arc.clockwise && arc.from_id != arc.to_id })
      expect(scene.write_back_spokes).to all(satisfy { |spoke| spoke.dashed && spoke.hub_gap == 6.0 })
      expect(scene.station_boxes.combination(2).none? { |a, b| SlimGraphR::Layout::Loop.overlap?(a.rect, b.rect) }).to be(true)
    end
    svg = loop_graph.to_svg(id: 'loop-geometry')
    expect(svg.scan('data-sgr-loop-cycle-arc=').size).to eq(5)
    expect(svg).to include('data-sgr-loop-cycle-arc="measure→capture"', 'marker-end="url(#loop-geometry-arrow)"')
    expect(svg.scan('data-sgr-loop-write-back=').size).to eq(5)
  end

  it 'renders all styles and light/dark themes with a twelve-pixel physical floor' do
    SlimGraphR::Style::PROFILES.keys.product(%i[light dark]).each do |style, theme|
      svg = loop_graph(style: style, theme: theme).to_svg(id: "loop-#{style}-#{theme}")
      expect(svg).to include(%(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}"), 'data-sgr-loop="true"')
      scale = svg[/data-sgr-display-scale="([\d.]+)"/, 1].to_f
      expect(scale * SlimGraphR::Layout::Loop::METADATA_TEXT_SIZE).to be >= 12
    end
  end

  it 'generates semantic descriptions and honors exact author replacement' do
    generated = CGI.unescapeHTML(loop_graph.to_svg(id: 'loop-description')[/<desc[^>]*>(.*?)<\/desc>/, 1])
    expect(generated).to include('clockwise', 'Capture → Research → Decide → Act → Measure → Capture')
    expect(generated).to include('Shared memory', 'SIGNALS', 'author-selected focal station')
    expect(loop_graph(description: 'Exact loop summary.').to_svg(id: 'custom')).to include('<desc id="custom-desc">Exact loop summary.</desc>')
  end

  it 'strictly rejects malformed, unknown, null, inferred, branch, skip, and coordinate JSON fields' do
    base = JSON.parse(File.read(File.expand_path('../examples/standalone/loop.json', __dir__), encoding: 'UTF-8'))
    mutations = [
      ->(d) { d['direction'] = 'counterclockwise' }, ->(d) { d.delete('cycle') },
      ->(d) { d['stations'][0]['focal'] = nil }, ->(d) { d['stations'][0]['x'] = 10 },
      ->(d) { d['stations'][0]['radius'] = 240 }, ->(d) { d['write_backs'][0]['to'] = nil },
      ->(d) { d['edges'] = [] }, ->(d) { d['branches'] = [] }, ->(d) { d['cycle'] << d['cycle'][0] }
    ]
    mutations.each do |mutation|
      data = Marshal.load(Marshal.dump(base)); mutation.call(data)
      expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error)
    end
  end
end
