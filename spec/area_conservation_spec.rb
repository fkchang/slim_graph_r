# frozen_string_literal: true
require 'bigdecimal'
require 'rexml/document'
require_relative 'spec_helper'
require_relative '../lib/slim_graph_r/document'
require_relative '../lib/slim_graph_r/cli'

RSpec.describe 'area and conservation quantitative diagrams' do
  def treemap(**options, &block)
    SlimGraphR.diagram(:treemap, title: 'Storage', unit: 'GiB', **options, &block)
  end

  def sankey(**options, &block)
    SlimGraphR.diagram(:sankey, title: 'CI minutes', unit: 'minutes', **options, &block)
  end

  def balanced_sankey(**options)
    sankey(**options) do
      stage :source, 'Input'; stage :work, 'Work'; stage :outcome, 'Outcome'
      node :ci, stage: :source, label: 'CI', value: 100
      node :test, stage: :work, label: 'Test', value: 60
      node :build, stage: :work, label: 'Build', value: 40
      node :passed, stage: :outcome, label: 'Passed', value: 90
      node :waste, stage: :outcome, label: 'Waste', value: 10
      flow :ci, :test, 60; flow :ci, :build, 40
      flow :test, :passed, 55; flow :test, :waste, 5
      flow :build, :passed, 35; flow :build, :waste, 5
    end
  end

  it 'keeps treemap and Sankey intrinsic canvases responsive without equal-width caps' do
    charts = [
      treemap { item :images, 'Images', 80; item :logs, 'Logs', 20 },
      balanced_sankey
    ]
    charts.each do |chart|
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

  it 'partitions exact treemap shares while retaining zero only as data and legend' do
    model = treemap do
      item :images, 'Images', 80
      item :logs, 'Logs', 20, focal: true
      item :archive, 'Archive', 0
    end
    expect(model).to be_frozen
    expect(model.items).to all(be_frozen)
    svg = model.to_svg(id: 'storage')
    doc = REXML::Document.new(svg)
    cells = REXML::XPath.match(doc, "//*[local-name()='rect' and @data-treemap-cell]")
    expect(cells.size).to eq(2)
    expect(cells.map { |cell| cell.attributes['data-share'].to_f }.sum).to be_within(1e-12).of(1.0)
    plot_area = cells.sum { |cell| cell.attributes['width'].to_f * cell.attributes['height'].to_f }
    expect(plot_area).to be_within(1e-6).of(model.layout.plot_width * model.layout.plot_height)
    expect(svg).to include('data-treemap-zero="archive"', 'Archive', 'data-area-total="100.0"')
    expect(svg).not_to include('data-treemap-cell="archive"')
  end

  it 'keeps a tiny positive treemap cell exact and moves its copy to a keyed legend' do
    model = treemap(precision: 6) do
      item :bulk, 'Bulk', 999_999
      item :trace, 'Trace 東京', 1
    end
    svg = model.to_svg(id: 'tiny-map')
    cell = REXML::XPath.first(REXML::Document.new(svg), "//*[local-name()='rect' and @data-treemap-cell='trace']")
    expect(cell.attributes['data-share']).to eq('0.000001')
    expect(cell.attributes['width'].to_f * cell.attributes['height'].to_f).to be_within(1e-5).of(model.layout.plot_width * model.layout.plot_height / 1_000_000.0)
    expect(svg).to include('data-external-legend="trace"', 'Trace 東京')
  end

  it 'rejects treemap invalid quantities, identities, cardinality, and focal count' do
    expect { treemap { item :a, 'A', 0; item :b, 'B', 0 } }.to raise_error(SlimGraphR::Error, /positive/)
    expect { treemap { item :a, 'A', -1; item :b, 'B', 2 } }.to raise_error(SlimGraphR::Error, /nonnegative/)
    expect { treemap { item :a, 'A', 1 } }.to raise_error(SlimGraphR::Error, /2–12/)
    expect { treemap { item :a, 'A', 1; item :a, 'B', 2 } }.to raise_error(SlimGraphR::Error, /unique/)
    expect { treemap { item :a, 'A', 1, focal: true; item :b, 'B', 2, focal: true } }.to raise_error(SlimGraphR::Error, /one focal/)
    expect { treemap { item :a, 'A', 0, focal: true; item :b, 'B', 2 } }.to raise_error(SlimGraphR::Error, /positive/)
  end

  it 'accepts only the shared finite Ruby numeric types and plain half-even formatting' do
    expect do
      treemap(precision: 2) { item :a, 'A', BigDecimal('1.245'); item :b, 'B', 1.255 }
    end.not_to raise_error
    [Rational(1, 2), Complex(1, 0), '1', nil, Float::NAN, Float::INFINITY].each do |bad|
      expect { treemap { item :a, 'A', 1; item :b, 'B', bad } }.to raise_error(SlimGraphR::Error, /finite Integer, Float, or BigDecimal/)
    end
    expect { treemap(notation: :scientific) { item :a, 'A', 1; item :b, 'B', 2 } }.to raise_error(SlimGraphR::Error, /plain/)
    expect { treemap(precision: 7) { item :a, 'A', 1; item :b, 'B', 2 } }.to raise_error(SlimGraphR::Error, /precision/)
  end

  it 'supports the 2 and 12 item treemap boundaries and detects Unicode-equivalent labels' do
    expect { treemap { item :a, 'A', 1; item :b, 'B', 2 } }.not_to raise_error
    expect do
      treemap { 12.times { |i| item "i#{i}", "Item #{i}", i + 1 } }
    end.not_to raise_error
    expect do
      treemap { item :a, 'Café', 1; item :b, "Cafe\u0301", 2 }
    end.to raise_error(SlimGraphR::Error, /labels must be unique/)
  end

  it 'uses one exact Sankey scale for node heights and ribbon thicknesses with disjoint offsets' do
    model = balanced_sankey
    svg = model.to_svg(id: 'flow')
    doc = REXML::Document.new(svg)
    metadata = REXML::XPath.first(doc, "//*[local-name()='metadata' and @data-conservation]")
    k = BigDecimal(metadata.attributes['data-px-per-unit'])
    expect(metadata.attributes['data-conservation']).to eq('strict-balanced')
    REXML::XPath.match(doc, "//*[@data-sankey-node]").each do |node|
      expect(BigDecimal(node.attributes['height'])).to eq(BigDecimal(node.attributes['data-value']) * k)
      expect(node.attributes['data-in-total']).not_to be_nil
      expect(node.attributes['data-out-total']).not_to be_nil
    end
    ribbons = REXML::XPath.match(doc, "//*[local-name()='path' and @data-sankey-flow]")
    expect(ribbons.size).to eq(6)
    ribbons.each do |flow|
      expect(BigDecimal(flow.attributes['data-thickness'])).to eq(BigDecimal(flow.attributes['data-value']) * k)
      expect(flow.attributes.values_at('data-source-offset-start', 'data-source-offset-end', 'data-target-offset-start', 'data-target-offset-end')).to all(be_truthy)
      expect(flow.attributes['d']).to match(/C [^ ]+,[^ ]+ [^ ]+,[^ ]+ [^ ]+,[^ ]+/)
    end
    expect(model.accessible_description).to include('strict conservation verified', 'stage totals 100 minutes')
  end

  it 'rejects every imbalance, nonadjacent or zero flow, wrong stage count, and unsupported balance' do
    expect do
      sankey do
        stage :a, 'A'; stage :b, 'B'; stage :c, 'C'
        node :x, stage: :a, label: 'X', value: 2
        node :y, stage: :b, label: 'Y', value: 1
        node :z, stage: :c, label: 'Z', value: 1
        flow :x, :y, 1; flow :y, :z, 1
      end
    end.to raise_error(SlimGraphR::Error, /outgoing total/)
    expect do
      sankey do
        stage :a, 'A'; stage :b, 'B'; stage :c, 'C'
        node :x, stage: :a, label: 'X', value: 1
        node :y, stage: :b, label: 'Y', value: 1
        node :z, stage: :c, label: 'Z', value: 1
        flow :x, :z, 1; flow :y, :z, 1
      end
    end.to raise_error(SlimGraphR::Error, /adjacent/)
    expect { balanced_sankey(balance: :repair) }.to raise_error(SlimGraphR::Error, /strict/)
    expect do
      sankey do
        stage :a, 'A'; stage :b, 'B'; stage :c, 'C'
        node :x, stage: :a, label: 'X', value: 1
        node :y, stage: :b, label: 'Y', value: 1
        node :z, stage: :c, label: 'Z', value: 1
        flow :x, :y, 0; flow :y, :z, 1
      end
    end.to raise_error(SlimGraphR::Error, /strictly positive flows/)
  end

  it 'preserves fractional Sankey values without grid or integer rounding' do
    model = sankey do
      stage :a, 'Entrée'; stage :b, 'Traitement'; stage :c, '結果'
      node :source, stage: :a, label: 'Source', value: 10.5
      node :one, stage: :b, label: 'One', value: 6.25
      node :two, stage: :b, label: 'Two', value: 4.25
      node :out, stage: :c, label: 'Out', value: 10.5
      flow :source, :one, 6.25; flow :source, :two, 4.25
      flow :one, :out, 6.25; flow :two, :out, 4.25
    end
    svg = model.to_svg(id: 'fractional')
    expect(svg).to include('data-value="6.25"', 'data-value="4.25"', 'STRICT CONSERVATION VERIFIED')
    expect(svg).not_to include('marker-end=', 'Other')
  end

  it 'raises an actionable layout error when the selected scale makes a ribbon thinner than one device pixel' do
    model = sankey do
      stage :a, 'A'; stage :b, 'B'; stage :c, 'C'
      node :source, stage: :a, label: 'Source', value: 1_000_000
      node :large, stage: :b, label: 'Large', value: 999_999
      node :tiny, stage: :b, label: 'Tiny', value: 1
      node :out, stage: :c, label: 'Out', value: 1_000_000
      flow :source, :large, 999_999; flow :source, :tiny, 1
      flow :large, :out, 999_999; flow :tiny, :out, 1
    end
    expect { model.to_svg }.to raise_error(SlimGraphR::LayoutError, /one device pixel.*aggregate|split/i)
  end

  it 'parses strict JSON into models and rejects null, unknown, cross-type, and nonnumeric values' do
    map_json = '{"type":"treemap","title":"Storage","unit":"GiB","items":[{"id":"images","label":"Images","value":80},{"id":"logs","label":"Logs","value":20,"focal":true},{"id":"archive","label":"Archive","value":0}]}'
    ruby_map = treemap { item :images, 'Images', 80; item :logs, 'Logs', 20, focal: true; item :archive, 'Archive', 0 }
    expect(SlimGraphR::Document.from_json(map_json)).to eq(ruby_map)
    flow_json = File.read(File.expand_path('../examples/standalone/sankey.json', __dir__), encoding: 'UTF-8')
    expect(SlimGraphR::Document.from_json(flow_json)).to eq(balanced_sankey(source_note: 'CI ledger · 2026-09-01 · includes explicit Waste'))
    [map_json.sub('"items"', '"wat":1,"items"'), map_json.sub('"unit":"GiB"', '"unit":null'), map_json.sub('"value":80', '"value":"80"'), map_json.sub('"items"', '"flows":[],"items"')].each do |json|
      expect { SlimGraphR::Document.from_json(json) }.to raise_error(SlimGraphR::Error)
    end
  end

  it 'renders paired standalone Ruby and JSON through the CLI' do
    %w[treemap sankey].each do |name|
      outputs = %w[rb json].map do |extension|
        output, errors = StringIO.new, StringIO.new
        status = SlimGraphR::CLI.run(['render', File.expand_path("../examples/standalone/#{name}.#{extension}", __dir__)], output: output, errors: errors)
        expect([status, errors.string]).to eq([0, ''])
        expect { REXML::Document.new(output.string) }.not_to raise_error
        output.string
      end
      expect(outputs[0]).to include("data-sgr-#{name}=\"true\"")
      expect(outputs[1]).to include("data-sgr-#{name}=\"true\"")
    end
  end
end
