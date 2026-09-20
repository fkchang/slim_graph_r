# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'bounded tree diagrams' do
  def elements(svg, xpath)
    document = REXML::Document.new(svg)
    REXML::XPath.match(document, xpath)
  end

  def reference_tree(**options)
    SlimGraphR.diagram(:tree, title: 'Service ownership', **options) do
      root :platform, 'Platform', detail: 'Shared foundation' do
        child :product, 'Product' do
          child :web, 'Web'
          child :api, 'API', focal: true
        end
        child :operations, 'Operations'
      end
    end
  end

  let(:json_data) do
    {
      type: 'tree', title: 'Service ownership',
      root: {
        id: 'platform', label: 'Platform', detail: 'Shared foundation',
        children: [
          { id: 'product', label: 'Product', children: [
            { id: 'web', label: 'Web' }, { id: 'api', label: 'API', focal: true }
          ] },
          { id: 'operations', label: 'Operations' }
        ]
      }
    }
  end

  it 'builds and freezes a nested single-parent hierarchy with an optional focal node' do
    graph = reference_tree
    expect(graph.tree_nodes.map { |item| [item.id, item.parent_id, item.depth, item.focal] }).to eq([
      ['platform', nil, 1, false], ['product', 'platform', 2, false],
      ['web', 'product', 3, false], ['api', 'product', 3, true], ['operations', 'platform', 2, false]
    ])
    expect(graph.tree_nodes).to be_frozen
    expect(graph.tree_nodes).to all(be_frozen)
    expect(graph.tree_nodes.first.label).to be_frozen
    expect do
      SlimGraphR.diagram(:tree) { root(:root) { child :leaf } }
    end.not_to raise_error
  end

  it 'keeps strict recursive JSON equivalent to Ruby and distinguishes null from omission' do
    parsed = SlimGraphR::Document.from_json(JSON.generate(json_data))
    expect(parsed.tree_nodes.map(&:to_h)).to eq(reference_tree.tree_nodes.map(&:to_h))
    expect(parsed.to_svg(id: 'tree-parity')).to eq(reference_tree.to_svg(id: 'tree-parity'))
    invalid = json_data.merge(root: json_data[:root].merge(detail: nil))
    expect { SlimGraphR::Document.from_json(JSON.generate(invalid)) }.to raise_error(SlimGraphR::Error)
    expect do
      SlimGraphR::Document.from_json(JSON.generate(json_data.merge(nodes: [])))
    end.to raise_error(SlimGraphR::Error, /cross-type/i)
  end

  it 'keeps the packaged Ruby and JSON examples equivalent' do
    examples_dir = File.expand_path('../examples/standalone', __dir__)
    ruby = eval(File.read(File.join(examples_dir, 'tree.rb'), encoding: 'UTF-8'), binding, File.join(examples_dir, 'tree.rb'))
    json = SlimGraphR::Document.from_json(File.read(File.join(examples_dir, 'tree.json'), encoding: 'UTF-8'))
    expect(json.to_svg(id: 'tree-example')).to eq(ruby.to_svg(id: 'tree-example'))
  end

  it 'enforces one root, global IDs, depth, breadth and zero-or-one focal node' do
    expect { SlimGraphR.diagram(:tree) {} }.to raise_error(SlimGraphR::Error, /exactly one root/i)
    expect { SlimGraphR.diagram(:tree) { child :orphan } }.to raise_error(SlimGraphR::Error, /inside a root or child/i)
    expect do
      SlimGraphR.diagram(:tree) { root(:a) {}; root(:b) {} }
    end.to raise_error(SlimGraphR::Error, /exactly one root/i)
    expect do
      SlimGraphR.diagram(:tree) { root(:same) { child :same } }
    end.to raise_error(SlimGraphR::Error, /IDs must be unique/i)
    expect do
      SlimGraphR.diagram(:tree) { root(:a) { child(:b) { child(:c) { child(:d) { child :e } } } } }
    end.to raise_error(SlimGraphR::Error, /depth.*four/i)
    expect do
      SlimGraphR.diagram(:tree) { root(:a) { 6.times { |i| child "c#{i}" } } }
    end.to raise_error(SlimGraphR::Error, /five children|breadth/i)
    expect do
      SlimGraphR.diagram(:tree) { root(:a, focal: true) { child :b, focal: true } }
    end.to raise_error(SlimGraphR::Error, /one focal/i)
    expect do
      SlimGraphR.diagram(:tree) do
        root(:root) do
          child(:left) { 3.times { |i| child "l#{i}" } }
          child(:right) { 3.times { |i| child "r#{i}" } }
        end
      end
    end.to raise_error(SlimGraphR::Error, /breadth.*tier 3/i)

    root_only = SlimGraphR.diagram(:tree) { root :only }
    expect(root_only.to_svg.scan(/data-sgr-tree-focal="true"/)).to be_empty
    restored = SlimGraphR.diagram(:tree) do
      root(:top) do
        child(:branch) { child :leaf }
        child :sibling
      end
    end
    expect(restored.tree_nodes.find { |item| item.id == 'sibling' }.parent_id).to eq('top')
  end

  it 'rejects recursive JSON duplicate IDs, excessive depth and unknown child fields' do
    duplicate = Marshal.load(Marshal.dump(json_data))
    duplicate[:root][:children][1][:id] = 'web'
    deep = { type: 'tree', root: { id: 'a', children: [{ id: 'b', children: [{ id: 'c', children: [{ id: 'd', children: [{ id: 'e' }] }] }] }] } }
    unknown = Marshal.load(Marshal.dump(json_data))
    unknown[:root][:children][0][:html] = '<b>x</b>'
    [duplicate, deep, unknown].each do |data|
      expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error)
    end
    parsed = SlimGraphR::Document.from_json(JSON.generate(json_data))
    expect(parsed.tree_nodes.flat_map { |item| [item.id, item.label, item.detail].compact }).to all(be_frozen)
  end

  it 'renders real sibling buses in both orientations and draws connectors before nodes' do
    down = reference_tree.to_svg(id: 'tree-down')
    right = reference_tree(direction: :right).to_svg(id: 'tree-right')
    expect(down).to include('data-sgr-tree="true"', 'data-sgr-tree-bus="platform"', 'data-sgr-tree-node="api"')
    expect(right).to include('data-sgr-tree-direction="right"', 'data-sgr-tree-bus="product"')
    expect(down.index('data-sgr-tree-bus')).to be < down.index('data-sgr-tree-node')
    expect(down.scan(/data-sgr-tree-drop=/).size).to eq(4)
    expect(down.scan(/data-sgr-tree-focal="true"/).size).to eq(1)
  end

  it 'keeps every stem, bus and drop axis-aligned, attached, and inside the viewBox' do
    %i[down right].each do |direction|
      svg = reference_tree(direction: direction).to_svg(id: "tree-#{direction}-geometry")
      root = REXML::Document.new(svg).root
      _x, _y, width, height = root.attributes['viewBox'].split.map(&:to_f)
      rects = elements(svg, '//*[@data-sgr-tree-node]').to_h do |rect|
        [rect.attributes['data-sgr-tree-node'], %w[x y width height].map { |key| rect.attributes[key].to_f }]
      end
      lines = elements(svg, '//*[@data-sgr-tree-stem or @data-sgr-tree-bus or @data-sgr-tree-drop]')
      expect(lines).not_to be_empty
      lines.each do |line|
        x1, y1, x2, y2 = %w[x1 y1 x2 y2].map { |key| line.attributes[key].to_f }
        expect(x1 == x2 || y1 == y2).to be(true)
        expect([x1, x2]).to all(be_between(0, width))
        expect([y1, y2]).to all(be_between(0, height))
      end
      elements(svg, '//*[@data-sgr-tree-stem]').each do |line|
        x, y, w, h = rects.fetch(line.attributes['data-sgr-tree-stem'])
        if direction == :down
          expect([line.attributes['x1'].to_f, line.attributes['y1'].to_f]).to eq([x + w / 2, y + h])
        else
          expect([line.attributes['x1'].to_f, line.attributes['y1'].to_f]).to eq([x + w, y + h / 2])
        end
      end
      elements(svg, '//*[@data-sgr-tree-drop]').each do |line|
        x, y, w, h = rects.fetch(line.attributes['data-sgr-tree-drop'])
        endpoint = [line.attributes['x2'].to_f, line.attributes['y2'].to_f]
        expect(endpoint).to eq(direction == :down ? [x + w / 2, y] : [x, y + h / 2])
      end
    end
  end

  it 'gives a root-only tree room for its ordinary title and keeps the root centered' do
    %i[down right].product(%i[editorial ruby blueprint mono]).each do |direction, style|
      graph = SlimGraphR.diagram(:tree, title: 'One accountable owner', direction: direction, style: style) do
        root :owner, 'Platform team'
      end
      scene = graph.layout
      box = scene.boxes.first
      expect(elements(graph.to_svg, '//*[@class="sgr-title"]').map(&:text)).to eq(['One accountable owner'])
      expect(box.center[0]).to eq(scene.width / 2.0)
      expect([box.width, box.height]).to eq([180, 40])
      expect([box.x, box.right]).to all(be_between(40, scene.width - 40))
      expect(scene.tree_connectors).to be_empty
    end
  end

  it 'translates the whole tree and its attached sibling bus when its title widens the canvas' do
    build = lambda do |title|
      SlimGraphR.diagram(:tree, title: title) do
        root(:root) { child :left; child :right }
      end.layout
    end
    small = build.call('Tree')
    wide = build.call('One accountable owner')
    offset = (wide.width - small.width) / 2.0
    expect(offset).to be > 0
    small.boxes.zip(wide.boxes).each do |before, after|
      expect([after.x, after.y, after.width, after.height]).to eq([before.x + offset, before.y, before.width, before.height])
    end
    original, translated = small.tree_connectors.first, wide.tree_connectors.first
    original_points = original.values_at(:stem, :bus).flatten(1) + original[:drops].flat_map { |drop| drop[:points] }
    moved_points = translated.values_at(:stem, :bus).flatten(1) + translated[:drops].flat_map { |drop| drop[:points] }
    expect(moved_points).to eq(original_points.map { |x, y| [x + offset, y] })
  end

  it 'measures bounded node text, supports all styles and themes, and replaces descriptions' do
    %i[editorial ruby blueprint mono].product(%i[light dark auto]).each do |style, theme|
      expect(reference_tree.with(style: style, theme: theme).to_svg).to include(%(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}"))
    end
    custom = SlimGraphR.diagram(:tree, description: 'Authored summary') { root :one }
    expect(custom.to_svg).to include('<desc', '>Authored summary</desc>')
    expect(custom.to_svg).not_to include('Tree hierarchy.')
    generated = reference_tree.to_svg
    expect(generated).to include('Tree hierarchy.', 'API, child of Product, focal.', 'Platform: Shared foundation, root.')
    expect do
      SlimGraphR.diagram(:tree) { root :one, 'W' * 80 }.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /shorten/i)
  end
end
