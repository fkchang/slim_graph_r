# frozen_string_literal: true
require 'bigdecimal'
require_relative 'spec_helper'
require_relative '../lib/slim_graph_r/document'

RSpec.describe 'Cartesian quantitative diagrams' do
  def bar(**options, &block)
    SlimGraphR.diagram(:bar, title: 'Net', unit: 'USD', **options, &block)
  end

  it 'builds immutable signed bars from exact zero and paints no zero rectangle' do
    model = bar do
      category :up, 'Up', 12
      category :down, 'Down', -4
      category :zero, 'Zero', 0, focal: true
    end
    svg = model.to_svg(id: 'bars')
    expect(model).to be_frozen
    expect(model.categories).to be_frozen
    expect(model.categories).to all(be_frozen)
    expect(svg).to include('data-sgr-bar="true"', 'data-domain-min="-4.0"', 'data-domain-max="12.0"')
    expect(svg.scan(/data-bar=/).size).to eq(2)
    expect(svg).to include('data-zero="true"', '>0 USD<')
  end

  it 'keeps the readable intrinsic bar canvas responsive without an equal-width cap' do
    svg = bar { category :up, 'Up', 12; category :down, 'Down', -4 }.to_svg(id: 'responsive-bar')
    root = svg[/<svg\b[^>]*>/]
    attributes = root.scan(/([\w:-]+)="([^"]*)"/).to_h
    view_width, view_height = attributes.fetch('viewBox').split.last(2).map(&:to_f)
    scale = attributes.fetch('data-sgr-display-scale').to_f

    expect(attributes.fetch('style')).to include('width:100%;height:auto', "min-width:#{attributes.fetch('width')}px")
    expect(attributes.fetch('style')).not_to include('max-width:')
    expect(attributes.fetch('width').to_i).to eq((view_width * scale).ceil)
    expect(attributes.fetch('height').to_i).to eq((view_height * scale).ceil)
  end

  it 'uses and discloses the exact all-zero reference domain' do
    model = bar { category(:a, 'A', 0); category(:b, 'B', 0) }
    expect([model.domain.min, model.domain.max].map(&:to_s)).to eq(%w[-0.1e1 0.1e1])
    expect(model.to_svg).to include('AUTO REFERENCE DOMAIN −1–1 USD', 'auto-reference="true"')
    expect(model.accessible_description).to include('AUTO REFERENCE DOMAIN', '-1 to 1')
  end

  it 'pins positive and negative constant auto domains' do
    positive = SlimGraphR.diagram(:line, title: 'P', unit: 'n') do
      x_axis :ordinal, domain: %w[A B C]
      series(:s, 'S') { 3.times { point 5 } }
    end
    negative = SlimGraphR.diagram(:line, title: 'N', unit: 'n') do
      x_axis :ordinal, domain: %w[A B C]
      series(:s, 'S') { 3.times { point(-5) } }
    end
    expect([positive.domain.min, positive.domain.max].map(&:to_s)).to eq(%w[0.0 0.6e1])
    expect([negative.domain.min, negative.domain.max].map(&:to_s)).to eq(%w[-0.6e1 0.0])
  end

  it 'accepts exactly Integer Float and finite BigDecimal values' do
    expect { bar { category(:a, 'A', 1); category(:b, 'B', BigDecimal('2.5')) } }.not_to raise_error
    [Rational(1, 2), Complex(1, 0), '1', nil, Float::NAN, Float::INFINITY].each do |bad|
      expect { bar { category(:a, 'A', 1); category(:b, 'B', bad) } }.to raise_error(SlimGraphR::Error, /finite Integer, Float, or BigDecimal/)
    end
  end

  it 'rejects unsafe Float conversion during SVG mapping' do
    expect do
      SlimGraphR.diagram(:scatter, title: 'Unsafe', x_unit: 'x', y_unit: 'y') do
        x_scale min: BigDecimal('1e-4000'), max: 1
        y_scale min: 0, max: 1
        point :a, 'A', x: BigDecimal('1e-4000'), y: 0
        point :b, 'B', x: 1, y: 1
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /underflow/)
  end

  it 'formats plain values at precision 0 through 6 using half-even' do
    model = bar(precision: 2) do
      category :a, 'A', BigDecimal('1.245')
      category :b, 'B', BigDecimal('1.255')
    end
    expect(model.to_svg).to include('>1.24 USD<', '>1.26 USD<')
    expect { bar(precision: 7) { category(:a, 'A', 1); category(:b, 'B', 2) } }.to raise_error(SlimGraphR::Error, /precision/)
    expect { bar(notation: :scientific) { category(:a, 'A', 1); category(:b, 'B', 2) } }.to raise_error(SlimGraphR::Error, /plain/)
  end

  it 'lays time points out by elapsed Gregorian days and disconnects gaps' do
    model = SlimGraphR.diagram(:line, title: 'Irregular', unit: 'count') do
      x_axis :time, domain: %w[2026-01-01 2026-01-02 2026-01-11 2026-01-21]
      series :api, 'API', focal: true do
        point 2
        gap reason: 'telemetry outage'
        point 5
        point 0
      end
    end
    svg = model.to_svg(id: 'line')
    xs = svg.scan(/data-x-index="(\d+)"[^>]+cx="([\d.]+)"/).to_h
    expect(xs['2'].to_f - xs['0'].to_f).to be_within(0.02).of((xs['3'].to_f - xs['0'].to_f) / 2.0)
    expect(svg.scan(/data-segment=/).size).to eq(1)
    expect(svg).to include('data-gap="true"', 'telemetry outage')
  end

  it 'keeps ordinal author order, equal spacing, and a visible warning' do
    model = SlimGraphR.diagram(:line, title: 'Stages', unit: 'ms') do
      x_axis :ordinal, domain: %w[Beta Alpha GA]
      series(:api, 'API') { point 3; point 2; point 1 }
    end
    svg = model.to_svg
    expect(svg).to include('SPACING IS ORDINAL, NOT ELAPSED TIME')
    expect(model.accessible_description).to match(/spacing is ordinal, not elapsed time/i)
  end

  it 'rejects invalid time order and incomplete series observations' do
    expect do
      SlimGraphR.diagram(:line, title: 'Bad', unit: 'n') do
        x_axis :time, domain: %w[2026-01-02 2026-01-01 2026-01-03]
        series(:s, 'S') { 3.times { point 1 } }
      end
    end.to raise_error(SlimGraphR::Error, /strictly ascending/)
    expect do
      SlimGraphR.diagram(:line, title: 'Bad', unit: 'n') do
        x_axis :ordinal, domain: %w[A B C]
        series(:s, 'S') { point 1; point 2 }
      end
    end.to raise_error(SlimGraphR::Error, /exactly one observation/)
  end

  it 'maps complete scatter points on required explicit signed scales' do
    model = SlimGraphR.diagram(:scatter, title: 'Position', x_unit: 'ms', y_unit: '%') do
      x_scale min: -10, max: 10
      y_scale min: -2, max: 2
      point :negative, 'Negative', x: -10, y: -2, annotate: true
      point :zero, 'Zero', x: 0, y: 0, focal: true, annotate: true
    end
    svg = model.to_svg(id: 'scatter')
    expect(svg).to include('data-sgr-scatter="true"', 'data-x="-10.0"', 'data-y="-2.0"')
    expect(svg).to match(/data-point="zero"[^>]+cx="[^\"]+"[^>]+cy="[^\"]+"/)
    expect(svg.scan(/data-annotation=/).size).to eq(2)
  end

  it 'enforces quantitative cardinality, uniqueness, focal, annotations, and domains' do
    expect { bar { category(:a, 'A', 1) } }.to raise_error(SlimGraphR::Error, /2–12/)
    expect { bar { category(:a, 'A', 1); category(:a, 'Again', 2) } }.to raise_error(SlimGraphR::Error, /unique/)
    expect { bar { category(:a, 'A', 1, focal: true); category(:b, 'B', 2, focal: true) } }.to raise_error(SlimGraphR::Error, /one focal/)
    expect do
      SlimGraphR.diagram(:scatter, title: 'A', x_unit: 'x', y_unit: 'y') do
        x_scale min: 0, max: 1; y_scale min: 0, max: 1
        4.times { |i| point "p#{i}", i.to_s, x: i.zero? ? 0 : 1, y: 0, annotate: true }
      end
    end.to raise_error(SlimGraphR::Error, /three annotations/)
  end

  it 'parses strict JSON into the same model and deterministic SVG' do
    ruby_model = bar(source_note: 'Ledger, 2026; bounds -10 to 30') do
      scale min: -10, max: 30
      category :north, 'North', 24
      category :south, 'South', -6
      category :online, 'Online', 0, focal: true
    end
    json = <<~JSON
      {"type":"bar","title":"Net","unit":"USD","source_note":"Ledger, 2026; bounds -10 to 30","scale":{"min":-10,"max":30},"categories":[{"id":"north","label":"North","value":24},{"id":"south","label":"South","value":-6},{"id":"online","label":"Online","value":0,"focal":true}]}
    JSON
    json_model = SlimGraphR::Document.from_json(json)
    expect(json_model).to eq(ruby_model)
    expect(json_model.to_svg(id: 'same')).to eq(ruby_model.to_svg(id: 'same'))
  end

  it 'rejects JSON nulls, unknown fields, cross-type fields, and non-numbers' do
    base = '{"type":"bar","title":"T","unit":"n","categories":[{"id":"a","label":"A","value":1},{"id":"b","label":"B","value":2}]'
    [' ,"description":null}', ',"wat":1}', ',"x_scale":{"min":0,"max":1}}'].each do |suffix|
      expect { SlimGraphR::Document.from_json(base + suffix) }.to raise_error(SlimGraphR::Error)
    end
    expect { SlimGraphR::Document.from_json(base.sub('"value":1', '"value":"1"') + '}') }.to raise_error(SlimGraphR::Error, /JSON number/)
    expect { SlimGraphR::Document.from_json('{"type":"architecture","x_scale":{"min":0,"max":1},"nodes":[],"edges":[]}') }.to raise_error(SlimGraphR::Error, /Only quantitative charts/)
  end

  it 'requires trimmed labels and detects canonically equivalent duplicates' do
    expect { bar { category(:a, ' A', 1); category(:b, 'B', 2) } }.to raise_error(SlimGraphR::Error, /trimmed/)
    composed = "Café"
    decomposed = "Cafe\u0301"
    expect { bar { category(:a, composed, 1); category(:b, decomposed, 2) } }.to raise_error(SlimGraphR::Error, /labels must be unique/)
  end

  it 'raises an actionable layout error before marks when labels cannot fit' do
    long = '幅' * 180
    expect do
      bar(orientation: :horizontal) { category(:a, long, 1); category(:b, 'B', 2) }.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /shorten.*label|enlarge.*canvas|split/i)
  end


  it 'reserves separate measured lanes for axes, category labels, and scale captions' do
    bar_svg = bar { category(:a, 'North', 1); category(:b, 'South', -1) }.to_svg(id: 'lane-bar')
    line_model = SlimGraphR.diagram(:line, title: 'Dates', unit: 'incidents/day') do
      x_axis :time, domain: %w[2026-01-01 2026-01-02 2026-01-11 2026-01-21]
      series(:api, 'API') { point 8; gap reason: 'outage'; point 3; point 5 }
    end
    line_svg = line_model.to_svg(id: 'lane-line')
    bar_doc, line_doc = REXML::Document.new(bar_svg), REXML::Document.new(line_svg)
    north = REXML::XPath.first(bar_doc, "//*[local-name()='text' and text()='North']")
    bar_caption = REXML::XPath.first(bar_doc, "//*[local-name()='text' and @data-scale-caption='true']")
    expect(bar_caption.attributes['y'].to_f - north.attributes['y'].to_f).to be >= 30
    dates = REXML::XPath.match(line_doc, "//*[local-name()='text' and @data-x-position]")
    date_boxes = dates.map do |text|
      width = SlimGraphR::Text.width(text.text, 12, font: :mono)
      [text.attributes['x'].to_f - width / 2, text.attributes['x'].to_f + width / 2]
    end
    expect(date_boxes.combination(2)).to all(satisfy { |a, b| a[1] + 8 <= b[0] || b[1] + 8 <= a[0] })
    line_caption = REXML::XPath.first(line_doc, "//*[local-name()='text' and @data-scale-caption='true']")
    expect(line_caption.attributes['y'].to_f - dates.first.attributes['y'].to_f).to be >= 30
    expect(line_model.accessible_description).not_to include(';;')
  end

  it 'chooses non-overlapping measured scatter annotation candidates' do
    model = SlimGraphR.diagram(:scatter, title: 'Labels', x_unit: 'ms', y_unit: '%') do
      x_scale min: -100, max: 600
      y_scale min: -2, max: 8
      point :cache, 'Caché − local', x: -40, y: -1, annotate: true
      point :zero, 'Zero origin', x: 0, y: 0, annotate: true
      point :pay, 'Payments 東京', x: 260, y: 2.8, annotate: true
    end
    doc = REXML::Document.new(model.to_svg(id: 'annotation'))
    boxes = REXML::XPath.match(doc, "//*[local-name()='text' and @data-annotation]").map do |text|
      width = SlimGraphR::Text.width(text.text, 14)
      x, y = text.attributes['x'].to_f, text.attributes['y'].to_f
      left = text.attributes['text-anchor'] == 'end' ? x - width : x
      [left, y - 15, left + width, y + 3]
    end
    expect(boxes.combination(2)).to all(satisfy { |a, b| a[2] + 5 <= b[0] || b[2] + 5 <= a[0] || a[3] + 5 <= b[1] || b[3] + 5 <= a[1] })
  end
end
