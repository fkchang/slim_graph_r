# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'bounded layer-stack diagrams' do
  def reference_layers(**options)
    SlimGraphR.diagram(:layers, title: 'Network path', **options) do
      layer :transport, 'Transport', index: 'L4', detail: 'TCP', focal: true
      layer :network, 'Network', index: 'L3', detail: 'IP'
      layer :link, 'Data link', index: 'L2', detail: 'Ethernet'
      layer :physical, 'Physical', index: 'L1', detail: 'Fiber'
    end
  end

  let(:json_data) do
    {
      type: 'layers', title: 'Network path', axis: 'Abstraction', indicator: 'up',
      layers: [
        { id: 'transport', label: 'Transport', index: 'L4', detail: 'TCP', focal: true },
        { id: 'network', label: 'Network', index: 'L3', detail: 'IP' },
        { id: 'link', label: 'Data link', index: 'L2', detail: 'Ethernet' },
        { id: 'physical', label: 'Physical', index: 'L1', detail: 'Fiber' }
      ]
    }
  end

  it 'builds a frozen ordered model with defaults and strict JSON parity' do
    graph = reference_layers
    expect([graph.axis, graph.indicator]).to eq(['Abstraction', :up])
    expect(graph.layers.map { |item| [item.id, item.index, item.detail, item.focal] }).to eq([
      ['transport', 'L4', 'TCP', true], ['network', 'L3', 'IP', false],
      ['link', 'L2', 'Ethernet', false], ['physical', 'L1', 'Fiber', false]
    ])
    expect(graph.layers).to be_frozen
    expect(graph.layers).to all(be_frozen)
    parsed = SlimGraphR::Document.from_json(JSON.generate(json_data))
    expect(parsed.to_svg(id: 'layers-parity')).to eq(graph.to_svg(id: 'layers-parity'))
  end

  it 'keeps the packaged Ruby and JSON examples equivalent' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = eval(File.read(File.join(root, 'layers.rb'), encoding: 'UTF-8'), binding, File.join(root, 'layers.rb'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'layers.json'), encoding: 'UTF-8'))
    expect(json.to_svg(id: 'layers-example')).to eq(ruby.to_svg(id: 'layers-example'))
  end

  it 'requires four to six rows, exactly one focal, unique IDs and unique indices' do
    expect do
      SlimGraphR.diagram(:layers) { 3.times { |i| layer "x#{i}", index: "T#{i}", focal: i.zero? } }
    end.to raise_error(SlimGraphR::Error, /four to six/i)
    expect do
      SlimGraphR.diagram(:layers) { 4.times { |i| layer "x#{i}", index: "T#{i}" } }
    end.to raise_error(SlimGraphR::Error, /exactly one focal/i)
    expect do
      SlimGraphR.diagram(:layers) { 4.times { |i| layer "x#{i}", index: 'SAME', focal: i.zero? } }
    end.to raise_error(SlimGraphR::Error, /indices must be unique/i)
    expect do
      SlimGraphR.diagram(:layers) { 4.times { |i| layer :same, index: "T#{i}", focal: i.zero? } }
    end.to raise_error(SlimGraphR::Error, /IDs must be unique/i)
    expect do
      SlimGraphR.diagram(:layers) { 4.times { |i| layer "x#{i}", index: "T#{i}", focal: i < 2 } }
    end.to raise_error(SlimGraphR::Error, /exactly one focal/i)
    [5, 6].each do |count|
      expect do
        SlimGraphR.diagram(:layers) { count.times { |i| layer "x#{i}", index: "T#{i}", focal: i.zero? } }
      end.not_to raise_error
    end
  end

  it 'rejects skipped, reversed-midstream, and mixed numeric indices but accepts semantic tags' do
    invalid = [%w[L4 L3 L1 L0], %w[4 3 4 5], %w[L4 L3 DOMAIN CORE]]
    invalid.each do |indices|
      expect do
        SlimGraphR.diagram(:layers) do
          indices.each_with_index { |index, i| layer "x#{i}", index: index, focal: i.zero? }
        end
      end.to raise_error(SlimGraphR::Error, /contiguous|mix numeric/i)
    end
    expect do
      SlimGraphR.diagram(:layers) do
        %w[EXPERIENCE APPLICATION DOMAIN FOUNDATION].each_with_index do |index, i|
          layer "x#{i}", index: index, focal: i.zero?
        end
      end
    end.not_to raise_error
    [%w[1 2 3 4], %w[4 3 2 1]].each do |indices|
      expect do
        SlimGraphR.diagram(:layers) do
          indices.each_with_index { |index, i| layer "x#{i}", index: index, focal: i.zero? }
        end
      end.not_to raise_error
    end
  end

  it 'distinguishes omitted JSON defaults from explicit null and rejects cross-type fields' do
    omitted = json_data.reject { |key, _| %i[axis indicator].include?(key) }
    expect(SlimGraphR::Document.from_json(JSON.generate(omitted)).axis).to eq('Abstraction')
    [json_data.merge(axis: nil), json_data.merge(indicator: nil), json_data.merge(root: {})].each do |data|
      expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error)
    end
    bad = json_data.merge(layers: json_data[:layers].map(&:dup))
    bad[:layers][1][:focal] = 'yes'
    expect { SlimGraphR::Document.from_json(JSON.generate(bad)) }.to raise_error(SlimGraphR::Error, /true or false/)
    parsed = SlimGraphR::Document.from_json(JSON.generate(json_data))
    expect([parsed.axis, *parsed.layers.flat_map { |item| [item.id, item.label, item.index, item.detail].compact }]).to all(be_frozen)
  end

  it 'renders measured uniform rows and a physically directed outside label in every presentation mode' do
    up = reference_layers.to_svg(id: 'layers-up')
    down = reference_layers(indicator: :down).to_svg(id: 'layers-down')
    expect(up).to include('data-sgr-layers="true"', 'data-sgr-layer="transport"', 'data-sgr-indicator="up"')
    expect(down).to include('data-sgr-indicator="down"')
    expect(up.scan(/data-sgr-layer-height="64"/).size).to eq(4)
    expect(up.scan(/data-sgr-layer-focal="true"/).size).to eq(1)
    up_scene = reference_layers.layout
    rects = up_scene.layer_rows.map { |entry| entry[:rect] }
    expect(rects.map { |rect| [rect[0], rect[2] - rect[0], rect[3] - rect[1]] }.uniq).to eq([[152, 800, 64]])
    expect(up_scene.direction_indicator[:x]).to be < rects.first[0]
    up_line = REXML::XPath.first(REXML::Document.new(up), '//*[@data-sgr-indicator="up"]')
    down_line = REXML::XPath.first(REXML::Document.new(down), '//*[@data-sgr-indicator="down"]')
    expect(up_line.attributes['y2'].to_f).to be < up_line.attributes['y1'].to_f
    expect(down_line.attributes['y2'].to_f).to be > down_line.attributes['y1'].to_f
    up_scene.layer_rows.each do |entry|
      expect(entry[:index_x]).to be < entry[:name_x]
      expect(entry[:name_x]).to be < entry[:detail_x]
    end
    expect(rects.flat_map { |rect| [rect[0], rect[1], rect[2], rect[3]] }).to all(be >= 0)
    %i[editorial ruby blueprint mono].product(%i[light dark auto]).each do |style, theme|
      expect(reference_layers.with(style: style, theme: theme).to_svg).to include(%(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}"))
    end
  end

  it 'budgets uppercase index tracking at the stack boundary without overlapping columns or the viewBox' do
    build = lambda do |index|
      SlimGraphR.diagram(:layers) do
        layer :wide, 'X', index: index, focal: true
        3.times { |i| layer "x#{i}", 'X', index: "TAG#{i}" }
      end
    end

    ['i' * 100, 'i' * 111, 'ß' * 55 + 'i'].each do |index|
      graph = build.call(index)
      scene = graph.layout
      row = scene.layer_rows.first
      svg = REXML::Document.new(graph.to_svg)
      rendered = REXML::XPath.first(svg, '//*[@class="sgr-layer-index"]')
      expect(rendered.text).to eq(index.upcase)
      expect(graph.layers.first.index).to eq(index)
      expect(graph.layers.first.index).to be_frozen
      tracked_width = SlimGraphR::Text.width(rendered.text, 9, font: :mono) + rendered.text.length * 9 * 0.08
      expect(rendered.attributes['x'].to_f + tracked_width + 28).to be <= row[:name_x]
      expect(row[:name_x] + SlimGraphR::Text.width('X', 15) + 48).to be <= row[:detail_x]
      expect(row[:detail_x] + 24).to eq(row[:rect][2])
      expect(row[:rect][2] + 40).to eq(svg.root.attributes['viewBox'].split.map(&:to_f)[2])
      expect(row[:rect][2] - row[:rect][0]).to eq(880) if index.upcase.length == 111
    end
    expect { build.call('i' * 112).to_svg }.to raise_error(SlimGraphR::LayoutError, /880px.*shorten/i)
  end

  it 'measures transformed labels and replaces generated descriptions' do
    custom = SlimGraphR.diagram(:layers, axis: 'ß' * 100, description: 'Exact layers summary') do
      4.times { |i| layer "x#{i}", index: "T#{i}", focal: i.zero? }
    end
    expect { custom.to_svg }.to raise_error(SlimGraphR::LayoutError, /axis.*shorten/i)
    ordinary = SlimGraphR.diagram(:layers, description: 'Exact layers summary') do
      4.times { |i| layer "x#{i}", index: "T#{i}", focal: i.zero? }
    end
    expect(ordinary.to_svg).to include('>Exact layers summary</desc>')
    expect(ordinary.to_svg).not_to include('Layer stack.')
    generated = reference_layers.to_svg
    expect(generated).to include('Layer stack.', 'Abstraction points up.', 'L4: Transport, TCP, focal')
    expect do
      SlimGraphR.diagram(:layers) do
        4.times { |i| layer "x#{i}", 'W' * 120, index: "T#{i}", focal: i.zero? }
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /shorten/i)
    expect do
      SlimGraphR.diagram(:layers) do
        layer :wide, index: 'I' * 120, focal: true
        3.times { |i| layer "x#{i}", index: "TAG#{i}" }
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /shorten/i)
  end
end
