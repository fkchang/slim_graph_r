require 'spec_helper'
require 'json'
require 'rexml/document'
require_relative '../lib/slim_graph_r/document'

RSpec.describe 'radial quantitative charts' do
  def polar(**options, &extra)
    SlimGraphR.diagram(:polar, title: 'Demand', unit: '% of peak', **options) do
      scale min: 0, max: 100
      category :north, 'North', 0
      category :east, 'East', 25
      category :south, 'South', 50, focal: true
      category :west, 'West', 100
      instance_eval(&extra) if extra
    end
  end

  def radar(**options)
    SlimGraphR.diagram(:radar, title: 'Scorecard', unit: 'score / 10', **options) do
      scale min: 0, max: 10
      criterion :quality, 'Quality'
      criterion :speed, 'Speed'
      criterion :cost, 'Cost'
      entity :alpha, 'Alpha', values: { quality: 0, speed: 5, cost: 10 }, focal: true
      entity :beta, 'Beta', values: { quality: 10, speed: 2.5, cost: 7 }
    end
  end

  it 'keeps polar and radar intrinsic canvases responsive without equal-width caps' do
    [polar, radar].each do |chart|
      root = chart.to_svg(id: "responsive-#{chart.type}")[/<svg\b[^>]*>/]
      attributes = root.scan(/([\w:-]+)="([^"]*)"/).to_h
      view_width, view_height = attributes.fetch('viewBox').split.last(2).map(&:to_f)
      scale = attributes.fetch('data-sgr-display-scale').to_f

      expect(attributes.fetch('style')).to include('width:100%;height:auto', "min-width:#{attributes.fetch('width')}px")
      expect(attributes.fetch('style')).not_to include('max-width:')
      expect(attributes.fetch('width').to_i).to eq((view_width * scale).ceil)
      expect(attributes.fetch('height').to_i).to eq((view_height * scale).ceil)
    end
  end

  it 'keeps exact immutable values and renders polar radius geometry without a zero ray' do
    chart = polar(precision: 2, source_note: 'Ledger · 2026-09-13 · scale 0–100')
    expect(chart).to be_frozen
    expect(chart.categories).to be_frozen
    expect(chart.categories.map(&:value)).to all(be_a(BigDecimal))
    svg = chart.to_svg(id: 'polar-proof')
    expect(svg).to include('data-polar-chart="true"', 'data-radius="0.0"', 'data-radius="40.0"', 'data-radius="80.0"', 'data-radius="160.0"')
    expect(svg).not_to include('data-polar-ray="north"', 'data-polar-marker="north"', '<path', '<polygon')
    expect(svg).to include('RADIUS = VALUE ON LINEAR 0–100 % of peak; AREA HAS NO MEANING', 'ray length/radius encodes value; area encodes nothing')
  end

  it 'reserves a distinct measured value baseline below every polar category at horizontal and diagonal angles' do
    chart = SlimGraphR.diagram(:polar, title: 'Unicode', unit: '%') do
      scale min: 0, max: 100
      %w[α β γ δ ε ζ η θ].each_with_index { |label, index| category "c#{index}", "Window #{label}", index * 10 }
    end
    document = REXML::Document.new(chart.to_svg(id: 'polar-label-lanes'))
    8.times do |index|
      category = REXML::XPath.first(document, "//*[@data-polar-category='c#{index}']")
      value = REXML::XPath.first(document, "//*[@data-polar-value='c#{index}']")
      expect(value.attributes['x'].to_f).to be_within(0.001).of(category.attributes['x'].to_f)
      expect(value.attributes['y'].to_f - category.attributes['y'].to_f).to be >= 24
      expect(value.attributes['text-anchor']).to eq(category.attributes['text-anchor'])
    end
  end

  it 'renders radar vertices at exact radii with outline-only colour-independent patterns' do
    svg = radar.to_svg(id: 'radar-proof')
    expect(svg).to include('data-radar-chart="true"', 'data-radar-entity="alpha"', 'data-radius="0.0"', 'data-radius="80.0"', 'data-radius="160.0"')
    expect(svg.scan(/data-radar-entity=/).size).to eq(2)
    expect(svg).to include('fill="none"', 'stroke-dasharray="6 4"', 'VERTEX RADIUS = SCORE ON LINEAR 0–10 score / 10; POLYGON AREA HAS NO MEANING')
    expect(svg).not_to match(/<polygon[^>]+fill="(?!none)/)
  end

  it 'round-trips strict JSON to the same model and deterministic SVG' do
    json = JSON.generate(type: 'radar', title: 'Scorecard', unit: 'score / 10', scale: { min: 0, max: 10 },
                         criteria: [{ id: 'quality', label: 'Quality' }, { id: 'speed', label: 'Speed' }, { id: 'cost', label: 'Cost' }],
                         entities: [{ id: 'alpha', label: 'Alpha', values: { quality: 0, speed: 5, cost: 10 }, focal: true },
                                    { id: 'beta', label: 'Beta', values: { quality: 10, speed: 2.5, cost: 7 } }])
    parsed = SlimGraphR::Document.from_json(json)
    expect(parsed).to eq(radar)
    expect(parsed.to_svg(id: 'same')).to eq(radar.to_svg(id: 'same'))
    reordered = JSON.parse(json)
    reordered['entities'][0]['values'] = { 'cost' => 10, 'quality' => 0, 'speed' => 5 }
    expect(SlimGraphR::Document.from_json(JSON.generate(reordered))).to eq(radar)
  end

  it 'rejects radial ambiguity, malformed values, and incomplete radar entities' do
    expect { SlimGraphR.diagram(:polar, unit: 'x') { scale min: 1, max: 10 } }.to raise_error(SlimGraphR::Error, /min must be exactly 0/)
    expect { polar { category :extra, 'Extra', -1 } }.to raise_error(ArgumentError)
    expect { SlimGraphR.diagram(:polar, unit: 'x') { scale min: 0, max: 10; 4.times { |i| category "c#{i}", "C#{i}", Rational(1, 2) } } }.to raise_error(SlimGraphR::Error, /finite Integer, Float, or BigDecimal/)
    expect do
      SlimGraphR.diagram(:radar, unit: 'x') do
        scale min: 0, max: 10
        criterion :a, 'A'; criterion :b, 'B'; criterion :c, 'C'
        entity :one, 'One', values: { a: 1, b: 2, c: 3 }
        entity :two, 'Two', values: { a: 1, b: 2 }
      end
    end.to raise_error(SlimGraphR::Error, /exactly the declared criteria/)
    expect { SlimGraphR::Document.from_json('{"type":"polar","unit":"x","scale":{"min":0,"max":1},"categories":[],"fill":true}') }.to raise_error(SlimGraphR::Error, /Unknown.*fields.*fill/)
    expect { SlimGraphR::Document.from_json('{"type":"radar","unit":"x","scale":{"min":0,"max":1},"criteria":null,"entities":[]}') }.to raise_error(SlimGraphR::Error, /criteria must be an array/)
  end

  it 'fails labels and legends that cannot be laid out faithfully' do
    expect { polar(title: 'x' * 300).to_svg }.to raise_error(SlimGraphR::LayoutError, /title.*shorten/i)
    expect do
      SlimGraphR.diagram(:radar, title: 'Wide', unit: 'score / 10') do
        scale min: 0, max: 10
        criterion :a, 'A' * 120; criterion :b, 'B'; criterion :c, 'C'
        entity :one, 'One', values: { a: 1, b: 2, c: 3 }
        entity :two, 'Two', values: { a: 3, b: 2, c: 1 }
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /table or small multiples/)
  end
end
