# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'DP integration diagrams' do
  def build(description: nil, &extra)
    SlimGraphR.diagram(:dp_integration, title: 'Declared platform · surfaces', description: description) do
      source :warehouse, 'Warehouse', kind: :database, detail: 'SQL'
      source :drop, 'Partner drop', kind: :file_drop, detail: 'SFTP'
      platform 'Data platform' do
        bar :query, 'Query service', role: 'SQL', focal: true, serves: true
        row do
          service :ingest, 'Ingest', role: 'INGEST', detail: 'ETL'
          service :store, 'Object store', role: 'STORE', detail: 'Objects', focal: true
          service :notebook, 'Notebook', role: 'ANALYSE'
        end
        bar :schedule, 'Scheduler', role: 'DAG'
      end
      consumer :reports, 'Reports', kind: :analytics, detail: 'ODBC'
      consumer :portal, 'Public portal', kind: :web, detail: 'HTTPS'
      layer_service :identity, 'Identity', kind: :identity, protocol: 'AUTH'
      wire :warehouse, :query, kind: :federated, protocol: 'JDBC'
      wire :drop, :ingest, kind: :ordinary, protocol: 'SFTP'
      wire :ingest, :store, kind: :ordinary, protocol: 'WRITE'
      wire :schedule, :ingest, kind: :trigger
      wire :query, :reports, kind: :serve, protocol: 'ODBC'
      wire :query, :portal, kind: :serve, protocol: 'HTTPS'
      instance_eval(&extra) if extra
    end
  end

  it 'preserves dedicated immutable records, containment order, and owned strings' do
    mutable = +'Source label'
    diagram = SlimGraphR.diagram(:dp_integration) do
      source :source, mutable, kind: :database
      platform('Platform') do
        bar :top, 'Top', role: 'SQL', focal: true, serves: true
        row do
          service :left, 'Left', role: 'INGEST'
          service :right, 'Right', role: 'STORE', focal: true
        end
      end
      consumer :result, kind: :analytics
      wire :source, :left, kind: :ordinary, protocol: 'JDBC'
      wire :top, :result, kind: :serve, protocol: 'ODBC'
    end
    mutable.replace('Changed')
    expect(diagram.integration_sources.first.label).to eq('Source label')
    expect(diagram.integration_platform.bands.map(&:kind)).to eq(%i[bar row])
    expect(diagram.integration_platform.bands.flat_map(&:items).map(&:id)).to eq(%w[top left right])
    expect(diagram.integration_sources).to be_frozen
    expect(diagram.integration_platform.bands).to be_frozen
    expect(diagram.integration_platform.bands.first.items.first).to be_frozen
  end

  it 'humanizes an omitted label but rejects an explicitly bad label in Ruby and JSON' do
    diagram = SlimGraphR.diagram(:dp_integration) do
      source :source_system, kind: :database
      platform 'Platform' do
        bar :query_service, role: 'SQL', focal: true, serves: true
        row do
          service :data_ingest
          service :object_store, focal: true
        end
      end
      consumer :report_reader, kind: :analytics
      wire :source_system, :data_ingest, kind: :ordinary, protocol: 'JDBC'
      wire :query_service, :report_reader, kind: :serve, protocol: 'ODBC'
    end
    expect(diagram.integration_sources.first.label).to eq('Source system')
    expect(diagram.integration_platform.bands.first.items.first.label).to eq('Query service')
    expect { SlimGraphR.diagram(:dp_integration) { source :bad, nil, kind: :database } }
      .to raise_error(SlimGraphR::Error, /label.*blank/)
    expect { SlimGraphR.diagram(:dp_integration) { source :bad, '  ', kind: :database } }
      .to raise_error(SlimGraphR::Error, /label.*blank/)

    json = File.read(File.expand_path('../examples/standalone/dp_integration.json', __dir__), encoding: 'UTF-8')
    omitted = SlimGraphR::Document.from_json(json.sub('"label": "Warehouse", ', ''))
    expect(omitted.integration_sources.first.label).to eq('Warehouse')
    expect { SlimGraphR::Document.from_json(json.sub('"label": "Warehouse"', '"label": null')) }
      .to raise_error(SlimGraphR::Error, /label must be a string/)
  end

  it 'restores nested scope after rescued row and platform errors' do
    expect do
      SlimGraphR.diagram(:dp_integration) do
        source :source, kind: :database
        platform 'Platform' do
          begin
            row { service :bad, 'Bad', role: 'X', unknown: true }
          rescue SlimGraphR::Error
          end
          bar :top, 'Top', role: 'SQL', focal: true, serves: true
          row do
            service :left, 'Left', role: 'INGEST'
            service :right, 'Right', role: 'STORE', focal: true
          end
        end
        consumer :result, kind: :analytics
        wire :source, :left, kind: :ordinary, protocol: 'JDBC'
        wire :top, :result, kind: :serve, protocol: 'ODBC'
      end
    end.not_to raise_error
  end

  it 'resolves forward wire references against the final declared model' do
    diagram = SlimGraphR.diagram(:dp_integration) do
      wire :source, :ingest, kind: :ordinary, protocol: 'JDBC'
      wire :query, :result, kind: :serve, protocol: 'ODBC'
      source :source, kind: :database
      consumer :result, kind: :analytics
      platform 'Platform' do
        bar :query, 'Query', role: 'SQL', focal: true, serves: true
        row do
          service :ingest, 'Ingest', role: 'IN'
          service :store, 'Store', role: 'ST', focal: true
        end
      end
    end
    expect(diagram.integration_wires.map(&:protocol)).to eq(%w[JDBC ODBC])
  end

  it 'enforces closed kinds, exact focal/serving counts, and one row' do
    expect { build { source :bad, kind: :bucket } }.to raise_error(SlimGraphR::Error, /kind must be one of/)
    expect { build { consumer :bad, kind: :desktop } }.to raise_error(SlimGraphR::Error, /kind must be one of/)
    expect { build { layer_service :bad, kind: :policy, protocol: 'X' } }.to raise_error(SlimGraphR::Error, /kind must be one of/)
    expect { build { service :extra, focal: true } }.to raise_error(SlimGraphR::Error)
    expect do
      SlimGraphR.diagram(:dp_integration) do
        source :s, kind: :database
        platform('P') { row { service :a, focal: true; service :b, focal: true, serves: true }; row { service :c } }
        wire :s, :a, kind: :ordinary, protocol: 'X'
      end
    end.to raise_error(SlimGraphR::Error, /exactly one row/)
  end

  it 'accepts only declared topology and explicit protocol semantics' do
    expect { build { wire :warehouse, :reports, kind: :ordinary, protocol: 'X' } }.to raise_error(SlimGraphR::Error, /source.*platform/i)
    expect { build { wire :ingest, :portal, kind: :serve, protocol: 'X' } }.to raise_error(SlimGraphR::Error, /serving component/)
    expect { build { wire :notebook, :store, kind: :trigger } }.to raise_error(SlimGraphR::Error, /originate from a bar/)
    expect { build { wire :schedule, :store, kind: :trigger, protocol: 'DAG' } }.to raise_error(SlimGraphR::Error, /unlabelled/)
    expect { build { wire :warehouse, :store, kind: :ordinary } }.to raise_error(SlimGraphR::Error, /protocol/)
    expect { build { wire :missing, :store, kind: :ordinary, protocol: 'X' } }.to raise_error(SlimGraphR::Error, /Unknown integration endpoint/)
  end

  it 'rejects generic graph aliases and arbitrary presentation/coordinates' do
    expect { build { node :generic } }.to raise_error(SlimGraphR::Error, /use source.*platform.*consumer/i)
    expect { build { edge :warehouse, :query } }.to raise_error(SlimGraphR::Error, /use wire/i)
    expect { build { source :bad, kind: :database, color: '#fff' } }.to raise_error(SlimGraphR::Error, /Unknown integration source options/)
    expect do
      SlimGraphR.diagram(:dp_integration) do
        source :s, kind: :database
        platform('P') { row { service :bad, x: 4 } }
      end
    end.to raise_error(SlimGraphR::Error, /Unknown integration component options/)
  end

  it 'parses strict nested JSON and matches Ruby SVG byte-for-byte with a stable id' do
    ruby = build
    json = File.read(File.expand_path('../examples/standalone/dp_integration.json', __dir__), encoding: 'UTF-8')
    parsed = SlimGraphR::Document.from_json(json)
    expect(parsed.integration_platform.bands.map(&:kind)).to eq(%i[bar row bar])
    expect(parsed.to_svg(id: 'stable')).to eq(ruby.to_svg(id: 'stable'))
  end

  it 'rejects null, unknown, malformed and cross-type JSON fields' do
    source = File.read(File.expand_path('../examples/standalone/dp_integration.json', __dir__), encoding: 'UTF-8')
    expect { SlimGraphR::Document.from_json(source.sub('"detail": "SQL"', '"detail": null')) }.to raise_error(SlimGraphR::Error)
    expect { SlimGraphR::Document.from_json(source.sub('"sources":', '"nodes": [], "sources":')) }.to raise_error(SlimGraphR::Error, /does not accept cross-type fields|Unknown/)
    expect { SlimGraphR::Document.from_json(source.sub('"kind": "database"', '"kind": "bucket"')) }.to raise_error(SlimGraphR::Error, /kind must be one of/)
    expect { SlimGraphR::Document.from_json(source.sub('"focal": true', '"focal": "yes"')) }.to raise_error(SlimGraphR::Error, /true or false/)
  end

  it 'renders fixed measured geometry, connectors first, boundary services, and effective focal CSS' do
    diagram = build
    scene = diagram.layout
    expect(scene.width).to eq(1240)
    expect(scene.zone.values_at(:x, :width)).to eq([260, 696])
    expect(scene.side_cards).to all(include(width: 160, height: 64))
    expect(scene.layer_services.first[:target][1]).to eq(scene.zone[:y] + scene.zone[:height])
    expect(scene.routes.map { |route| route[:source_port] }.uniq.size).to eq(scene.routes.size)
    boxes = (scene.side_cards + scene.components).to_h { |card| [card[:item].id, card] }
    scene.routes.each do |route|
      expect(route[:points].values_at(0, -1)).to eq([route[:source_port], route[:target_port]])
      [[route[:wire].from, route[:source_port]], [route[:wire].to, route[:target_port]]].each do |id, (x, y)|
        card = boxes.fetch(id)
        expect(x).to be_between(card[:x], card[:x] + card[:width])
        expect(y).to be_between(card[:y], card[:y] + card[:height])
        expect([card[:x], card[:x] + card[:width]].include?(x) || [card[:y], card[:y] + card[:height]].include?(y)).to be(true)
      end
    end
    expect(scene.routes.reject { |route| route[:wire].kind == :trigger }).to all(include(:label))
    expect(scene.routes.select { |route| route[:wire].kind == :trigger }.map { |route| route[:label] }).to all(be_nil)
    scene.routes.filter_map { |route| route[:label] }.each do |label|
      expect(scene.components).not_to include(satisfy { |card|
        SlimGraphR::Layout::Geometry.overlaps?(label[:rect], [card[:x], card[:y], card[:x] + card[:width], card[:y] + card[:height]])
      })
    end
    svg = diagram.to_svg(id: 'integration')
    expect(svg).to include('data-sgr-dp-integration="true"', 'data-sgr-platform-zone="true"',
                           'data-sgr-layer-service="identity"', 'data-sgr-boundary-target="true"')
    expect(svg.index('data-sgr-integration-wire')).to be < svg.index('data-sgr-integration-component')
    expect(svg).to include('#integration .sgr-integration-focal{fill:var(--sgr-tint)')
    expect(svg).to include('data-sgr-text-lane="detail"', 'data-sgr-text-lane="kind"')
    expect { REXML::Document.new(svg) }.not_to raise_error
  end

  it 'measures tracked uppercase labels and raises actionable layout failures' do
    expect { build { layer_service :long, 'Layer', kind: :backup, protocol: 'THIS PROTOCOL LABEL IS FAR TOO LONG FOR ITS RESERVED ROUTE' }.layout }
      .to raise_error(SlimGraphR::LayoutError, /shorten.*split|split.*shorten/i)
    expect { build { source :long, 'A source label that is far too long for a fixed integration card', kind: :database }.layout }
      .to raise_error(SlimGraphR::LayoutError, /shorten/i)
  end

  it 'generates complete descriptions and lets a custom description replace them' do
    description = build.to_svg(id: 'described')[/<desc[^>]*>(.*?)<\/desc>/, 1]
    expect(description).to include('Warehouse', 'Query service', 'focal', 'serving', 'Identity', 'AUTH', 'JDBC', 'HTTPS')
    custom = build(description: 'Exact author description').to_svg(id: 'custom')
    expect(custom).to include('<desc id="custom-desc">Exact author description</desc>')
    expect(custom[/<desc[^>]*>(.*?)<\/desc>/, 1]).not_to include('Warehouse')
  end

  it 'renders every style in light and dark with portable XML' do
    SlimGraphR::Style.names.product(%i[light dark]).each do |style, theme|
      svg = build.with(style: style, theme: theme).to_svg(id: "#{style}-#{theme}")
      expect(svg).to include(%(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}"))
      expect { REXML::Document.new(svg) }.not_to raise_error
    end
  end

  def fixture_with
    data = JSON.parse(File.read(File.expand_path('../examples/standalone/dp_integration.json', __dir__)))
    yield data
    SlimGraphR::Document.from_json(JSON.generate(data))
  end

  it 'keeps ordinary focal-adjacent wires consistent with their declared legend style' do
    doc = REXML::Document.new(build.to_svg(id: 'kinds'))
    wire = REXML::XPath.first(doc, "//*[@data-sgr-integration-wire='ingest-store']")
    legend = REXML::XPath.first(doc, "//*[@data-sgr-integration-legend-wire='ordinary']")
    expect(wire.attributes['stroke']).to eq(legend.attributes['stroke'])
    expect(wire.attributes['marker-end']).to eq('url(#kinds-arrow)')
  end

  it 'keeps protocol masks eight pixels from their wires and clear of all other routes and cards' do
    scene = build.layout
    labels = scene.routes.filter_map { |route| route[:label] }
    labels.combination(2) { |a, b| expect(SlimGraphR::Layout::Geometry.overlaps?(a[:rect], b[:rect])).to be(false) }
    scene.routes.each do |route|
      next unless route[:label]
      x, y, right, bottom = route[:label][:rect]
      scene.routes.each do |other|
        padding = route == other ? 8 : 2
        other[:points].each_cons(2) do |a, b|
          expect(SlimGraphR::Layout::Geometry.blocked?(a, b, [x - padding, y - padding, right + padding, bottom + padding])).to be(false)
        end
      end
      (scene.side_cards + scene.components).each do |card|
        expect(SlimGraphR::Layout::Geometry.overlaps?(route[:label][:rect], [card[:x], card[:y], card[:x] + card[:width], card[:y] + card[:height]])).to be(false)
      end
    end
  end

  it 'reserves independent footer cards, boundary routes and tracked protocol masks for three layer services' do
    diagram = fixture_with do |data|
      data['layer_services'] = %w[identity backup secrets].map { |kind| { 'id' => kind, 'kind' => kind, 'protocol' => 'ABCDEFGHIJ' } }
    end
    scene = diagram.layout
    doc = REXML::Document.new(diagram.to_svg(id: 'layers'))
    masks = REXML::XPath.match(doc, "//*[@data-sgr-layer-protocol-mask]").map do |node|
      x, y, width, height = %w[x y width height].map { |key| node.attributes[key].to_f }
      [x, y, x + width, y + height]
    end
    masks.combination(2) { |a, b| expect(SlimGraphR::Layout::Geometry.overlaps?(a, b)).to be(false) }
    scene.layer_services.each do |entry|
      expect(entry[:target][1]).to eq(scene.zone[:y] + scene.zone[:height])
      expect(entry[:source][1]).to eq(entry[:y])
      scene.layer_services.reject { |other| other == entry }.each do |other|
        rect = [other[:x], other[:y], other[:x] + other[:width], other[:y] + other[:height]]
        expect(SlimGraphR::Layout::Geometry.blocked?(entry[:source], entry[:target], rect)).to be(false)
      end
    end
  end

  it 'contains a thirteen-character bar role and its measured tracked text' do
    diagram = fixture_with { |data| data['platform']['rows'][0]['items'][0]['role'] = 'ABCDEFGHIJKLM' }
    doc = REXML::Document.new(diagram.to_svg(id: 'roles'))
    role = REXML::XPath.first(doc, "//text[.='ABCDEFGHIJKLM']")
    badge = role.previous_element
    card = REXML::XPath.first(doc, "//*[@data-sgr-integration-component='query']")
    expect(badge.attributes['x'].to_f + badge.attributes['width'].to_f).to be <= card.attributes['x'].to_f + card.attributes['width'].to_f - 8
    measured = SlimGraphR::Text.width('ABCDEFGHIJKLM', 8, font: :mono) + 12 * 0.6
    expect(badge.attributes['width'].to_f).to be >= measured + 14
  end
end
