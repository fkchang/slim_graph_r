# frozen_string_literal: true
require 'spec_helper'
require 'json'
require 'slim_graph_r/document'

RSpec.describe 'bounded quadrant diagrams' do
  def build(style: :editorial, theme: :light)
    SlimGraphR.diagram(:quadrant, title: 'Platform priorities · 優先順位', style: style, theme: theme) do
      horizontal_axis low: 'EASY', high: 'HARD'
      vertical_axis low: 'LOW IMPACT', high: 'HIGH IMPACT'
      item :cache, 'Cache migration', x: 0.72, y: 0.66, focal: true
      item :audit, 'Audit trail', x: -0.58, y: 0.34
      item :cleanup, 'Lint cleanup', x: -0.42, y: -0.46
      item :docs, 'Documentation', x: 0.35, y: -0.62
    end
  end

  it 'fits the exact atlas quadrant while keeping every point and label in its authored region' do
    scene = build.layout
    expect(scene.width).to eq(904)
    expect(build.to_svg(id: 'atlas-quadrant')).to include('viewBox="0 0 904 ', 'width="1356"', 'min-width:1356px')
    scene.points.each do |point|
      left, top, right, bottom = point.label_rect
      expect(left).to be >= scene.plot[0]
      expect(right).to be <= scene.plot[0] + scene.plot[2]
      expect(top).to be >= scene.plot[1]
      expect(bottom).to be <= scene.plot[1] + scene.plot[3]
      expect((left + right) / 2 < scene.center_x).to eq(point.item.x.negative?)
      expect((top + bottom) / 2 < scene.center_y).to eq(point.item.y.positive?)
    end
  end

  it 'keeps immutable dedicated authored records and exact linear point mapping' do
    diagram = build
    expect(diagram.items.map(&:to_h)).to eq([
      { id: 'cache', label: 'Cache migration', x: 0.72, y: 0.66, focal: true },
      { id: 'audit', label: 'Audit trail', x: -0.58, y: 0.34, focal: false },
      { id: 'cleanup', label: 'Lint cleanup', x: -0.42, y: -0.46, focal: false },
      { id: 'docs', label: 'Documentation', x: 0.35, y: -0.62, focal: false }
    ])
    expect(diagram.items).to be_frozen
    expect(diagram.items).to all(be_frozen)
    point = diagram.layout.points.first
    expect(point.cx).to eq(SlimGraphR::Layout::Quadrant::PLOT_LEFT + 0.86 * SlimGraphR::Layout::Quadrant::PLOT_WIDTH)
    expect(point.cy).to be_within(1e-12).of(SlimGraphR::Layout::Quadrant::PLOT_TOP + 0.17 * SlimGraphR::Layout::Quadrant::PLOT_HEIGHT)
    expect(point.item.x).to eq(0.72)
    expect(point.item.y).to eq(0.66)
  end

  it 'constructs byte-identical Ruby and strict JSON diagrams with a fixed ID' do
    json = File.read(File.expand_path('../examples/standalone/quadrant.json', __dir__), encoding: 'UTF-8')
    from_json = SlimGraphR::Document.from_json(json)
    ruby = TOPLEVEL_BINDING.eval(File.read(File.expand_path('../examples/standalone/quadrant.rb', __dir__), encoding: 'UTF-8'))
    expect(from_json.items.map(&:to_h)).to eq(ruby.items.map(&:to_h))
    expect(from_json.to_svg(id: 'quadrant-contract')).to eq(ruby.to_svg(id: 'quadrant-contract'))
  end

  it 'rejects non-finite, out-of-range, zero, and central safety-band coordinates' do
    [-Float::INFINITY, Float::NAN, 1.01, -1.01, 0, 0.03, -0.03].each do |value|
      expect do
        SlimGraphR.diagram(:quadrant) do
          horizontal_axis low: 'LEFT', high: 'RIGHT'; vertical_axis low: 'LOW', high: 'HIGH'
          item :a, 'A', x: value, y: 0.5; item :b, 'B', x: -0.5, y: -0.5
        end
      end.to raise_error(SlimGraphR::Error, /finite|\[-1, 1\]|safety band/)
    end
  end

  it 'accepts endpoint coordinates without snapping and rejects invalid structure' do
    diagram = SlimGraphR.diagram(:quadrant) do
      horizontal_axis low: 'LEFT', high: 'RIGHT'; vertical_axis low: 'BOTTOM', high: 'TOP'
      item :a, 'Edge A', x: -1, y: 1; item :b, 'Edge B', x: 1, y: -1
    end
    expect(diagram.layout.points.map { |p| [p.cx, p.cy] }).to eq([[92.0, 68.0], [812.0, 548.0]])
    expect { SlimGraphR.diagram(:quadrant) { item :a, 'A', x: 0.5, y: 0.5; item :b, 'B', x: -0.5, y: -0.5 } }.to raise_error(SlimGraphR::Error, /horizontal_axis/)
    expect { build.tap { |d| d.items << :x } }.to raise_error(FrozenError)
  end

  it 'enforces literal axes, 2–12 unique items, strict booleans, and one optional focal' do
    expect do
      SlimGraphR.diagram(:quadrant) do
        horizontal_axis low: 'L', high: 'H'; vertical_axis low: 'B', high: 'T'
        item :a, 'A', x: 0.5, y: 0.5, focal: true
        item :b, 'B', x: -0.5, y: -0.5, focal: true
      end
    end.to raise_error(SlimGraphR::Error, /at most one focal/)
    expect do
      SlimGraphR.diagram(:quadrant) do
        horizontal_axis low: '', high: 'H'; vertical_axis low: 'B', high: 'T'
        item :a, 'A', x: 0.5, y: 0.5; item :b, 'B', x: -0.5, y: -0.5
      end
    end.to raise_error(SlimGraphR::Error, /must not be blank/)
    expect do
      SlimGraphR.diagram(:quadrant) do
        horizontal_axis low: 'L', high: 'H'; vertical_axis low: 'B', high: 'T'
        item :a, 'A', x: 0.5, y: 0.5, focal: nil; item :b, 'B', x: -0.5, y: -0.5
      end
    end.to raise_error(SlimGraphR::Error, /true or false/)
  end

  it 'uses the shared defaults and rejects quadrant DSL or JSON fields on other types' do
    diagram = SlimGraphR.diagram(:quadrant) do
      horizontal_axis low: 'LEFT', high: 'RIGHT'; vertical_axis low: 'LOW', high: 'HIGH'
      item :a, 'A', x: 0.5, y: 0.5; item :b, 'B', x: -0.5, y: -0.5
    end
    expect([diagram.direction, diagram.style, diagram.theme, diagram.scale]).to eq(%i[down editorial light auto])
    expect do
      SlimGraphR.diagram(:architecture) { horizontal_axis low: 'LEFT', high: 'RIGHT' }
    end.to raise_error(SlimGraphR::Error, /only in a quadrant/)
    expect do
      SlimGraphR::Document.from_json(JSON.generate(type: 'architecture', horizontal_axis: { low: 'LEFT', high: 'RIGHT' }))
    end.to raise_error(SlimGraphR::Error, /Only a quadrant diagram accepts: horizontal_axis/)
  end

  it 'renders literal tip copy, caption, dot geometry, and readable text in every style and theme' do
    SlimGraphR::Style::PROFILES.keys.product(%i[light dark]).each do |style, theme|
      svg = build(style: style, theme: theme).to_svg(id: "quadrant-#{style}-#{theme}")
      expect(svg).to include('data-sgr-quadrant="true"', 'data-sgr-quadrant-caption="true"')
      expect(svg).to include('Positions are qualitative author judgments, not calculated scores.')
      expect(svg).to include('>EASY<', '>HARD<', '>LOW IMPACT<', '>HIGH IMPACT<')
      expect(svg).not_to include('↑', '↓', '→', '←', 'HIGH / LOW', 'score="')
      expect(svg).to include('data-sgr-display-scale="1.5"', 'font-size:8px', 'font-size:10px')
      expect(svg.scan('data-sgr-quadrant-point=').size).to eq(4)
      expect(svg.scan('data-sgr-quadrant-focal="true"').size).to eq(1)
    end
  end

  it 'keeps long Unicode labels inside their authored quadrants and clear of protected geometry' do
    scene = SlimGraphR.diagram(:quadrant) do
      horizontal_axis low: '小さな変更', high: '大きな変更'; vertical_axis low: '低い影響', high: '高い影響'
      item :a, '監査ログの移行', x: -0.72, y: 0.72
      item :b, '決済キャッシュ更新', x: 0.72, y: 0.72, focal: true
      item :c, '古い警告の整理', x: -0.72, y: -0.72
      item :d, '運用文書の更新', x: 0.72, y: -0.72
    end.layout
    scene.points.each do |point|
      left, top, right, bottom = point.label_rect
      expect((left + right) / 2 < scene.center_x).to eq(point.item.x.negative?)
      expect((top + bottom) / 2 < scene.center_y).to eq(point.item.y.positive?)
    end
  end

  it 'raises an actionable layout error instead of moving authored points when labels cannot fit' do
    diagram = SlimGraphR.diagram(:quadrant) do
      horizontal_axis low: 'LEFT', high: 'RIGHT'; vertical_axis low: 'LOW', high: 'HIGH'
      item :a, 'A label that is deliberately far too long to fit in its authored quadrant while preserving every boundary and point', x: 0.09, y: 0.09
      item :b, 'B', x: -0.5, y: -0.5
    end
    expect { diagram.to_svg }.to raise_error(SlimGraphR::LayoutError, /shorten the label|spread the authored positions|split the quadrant/)
    expect(diagram.items.first.x).to eq(0.09)
  end

  it 'generates qualitative authored-position descriptions without inferred recommendations' do
    svg = build.to_svg(id: 'quadrant-description')
    desc = CGI.unescapeHTML(svg[/<desc[^>]*>(.*?)<\/desc>/, 1])
    expect(desc).to include('Cache migration is authored toward HARD and HIGH IMPACT; selected as the focal discussion point')
    expect(desc).to include('Positions are qualitative author judgments, not calculated scores.')
    expect(desc).not_to match(/is recommended|priority score|do first/i)
  end

  it 'strictly rejects nulls, unknown keys, wrong types, cross-type keys, and score fields' do
    base = JSON.parse(File.read(File.expand_path('../examples/standalone/quadrant.json', __dir__), encoding: 'UTF-8'))
    mutations = [
      ->(d) { d['items'][0]['focal'] = nil }, ->(d) { d['items'][0]['score'] = 9 },
      ->(d) { d['items'][0]['x'] = '0.5' }, ->(d) { d['horizontal_axis']['middle'] = 'MEDIUM' },
      ->(d) { d['nodes'] = [] }, ->(d) { d['vertical_axis'] = nil }
    ]
    mutations.each do |mutation|
      data = Marshal.load(Marshal.dump(base)); mutation.call(data)
      expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error)
    end
  end
end
