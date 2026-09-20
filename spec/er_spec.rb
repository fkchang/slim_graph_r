# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/document'
require 'json'
require 'rexml/document'

RSpec.describe 'entity-relationship diagrams' do
  def build(description: nil)
    SlimGraphR.diagram(:er, title: 'Order domain · 注文', description: description) do
      entity :customer, 'Customer' do
        field :customer_id, 'customer_id', key: :primary
        field :email, 'email'
      end
      entity :order, 'Order', focal: true do
        field :order_id, 'order_id', key: :primary
        field :customer_id, 'customer_id', key: :foreign
        field :placed_at, 'placed_at'
      end
      relationship :customer, :order, from: '1', to: '0..*', label: 'places'
    end
  end

  it 'owns immutable conceptual records with field IDs scoped per entity' do
    diagram = build
    expect(diagram.entities.map(&:id)).to eq(%w[customer order])
    expect(diagram.entities.map { |e| e.fields.map(&:id) }).to eq([%w[customer_id email], %w[order_id customer_id placed_at]])
    expect(diagram.relationships.map { |r| [r.from, r.to, r.from_cardinality, r.to_cardinality] })
      .to eq([%w[customer order 1 0..*]])
    expect(diagram.entities).to be_frozen
    expect(diagram.entities.all?(&:frozen?)).to be(true)
    expect(diagram.entities.flat_map(&:fields).all?(&:frozen?)).to be(true)
    expect(diagram.relationships.all?(&:frozen?)).to be(true)
  end

  it 'copies caller strings and restores entity scope after rescued block errors' do
    label = +'Customer'
    field_label = +'customer_id'
    diagram = SlimGraphR.diagram(:er) do
      begin
        entity :bad, 'Bad' do
          field :id, 'id'
          raise 'rescued'
        end
      rescue RuntimeError
      end
      entity :customer, label do
        field :customer_id, field_label
      end
      entity :order, 'Order' do
        field :customer_id, 'customer_id'
      end
      relationship :customer, :order, from: '1', to: 'N'
    end
    label.replace('Changed'); field_label.replace('Changed')
    expect(diagram.entities.map(&:id)).to eq(%w[bad customer order])
    expect(diagram.entities[1].label).to eq('Customer')
    expect(diagram.entities[1].fields.first.label).to eq('customer_id')
    expect { SlimGraphR.diagram(:er) { field :outside, 'outside' } }.to raise_error(SlimGraphR::Error, /inside an entity/i)
    expect do
      SlimGraphR.diagram(:er) { entity(:outer, 'Outer') { entity(:inner, 'Inner') { field :id, 'id' } } }
    end.to raise_error(SlimGraphR::Error, /cannot be nested/i)
    expect do
      SlimGraphR.diagram(:er) { entity(:a, 'A') { relationship :a, :b, from: '1', to: 'N' } }
    end.to raise_error(SlimGraphR::Error, /outside entity blocks/i)
  end

  it 'validates budgets, identities, references, booleans, keys, cardinalities, and duplicate relationships' do
    expect { SlimGraphR.diagram(:er, direction: :right) {} }.to raise_error(SlimGraphR::Error, /fixed.*down/i)
    expect { SlimGraphR.diagram(:er) { entity :a, 'A', focal: 'true' } }.to raise_error(SlimGraphR::Error, /focal.*true or false/i)
    expect do
      SlimGraphR.diagram(:er) { entity(:a, 'A') { field :id, 'id', key: :unique } }
    end.to raise_error(SlimGraphR::Error, /key.*primary.*foreign/i)
    expect do
      SlimGraphR.diagram(:er) do
        entity(:a, 'A') { field :id, 'id' }
        entity(:b, 'B') { field :id, 'id' }
        relationship :a, :b, from: 'many', to: '1'
      end
    end.to raise_error(SlimGraphR::Error, /cardinality/i)
    expect do
      SlimGraphR.diagram(:er) do
        entity(:a, 'A') { field :id, 'id' }
        entity(:b, 'B') { field :id, 'id' }
        relationship :a, :missing, from: '1', to: 'N'
      end
    end.to raise_error(SlimGraphR::Error, /unknown.*missing/i)
    expect do
      SlimGraphR.diagram(:er) do
        entity(:a, 'A') { field :id, 'id' }
        entity(:b, 'B') { field :id, 'id' }
        relationship :a, :b, from: '1', to: 'N'
        relationship :b, :a, from: 'N', to: '1'
      end
    end.to raise_error(SlimGraphR::Error, /duplicate relationship/i)
  end

  it 'rejects generic graph, physical-schema, and cross-family DSL without inference' do
    expect { SlimGraphR.diagram(:er) { node :x } }.to raise_error(SlimGraphR::Error, /dedicated.*ER/i)
    expect { SlimGraphR.diagram(:er) { edge :x, :y } }.to raise_error(SlimGraphR::Error, /relationship/i)
    expect { SlimGraphR.diagram(:er) { group(:x) {} } }.to raise_error(SlimGraphR::Error, /does not accept groups/i)
    expect { SlimGraphR.diagram(:er) { table :x } }.to raise_error(SlimGraphR::Error, /database-schema/)
    expect(build.relationships.size).to eq(1)
  end

  it 'round trips strict JSON to the same model, description, and fixed-ID SVG' do
    path = File.expand_path('../examples/standalone/entity_relationships.json', __dir__)
    parsed = SlimGraphR::Document.from_json(File.read(path, encoding: 'UTF-8'))
    load File.expand_path('../examples/standalone/entity_relationships.rb', __dir__)
    ruby = SlimGraphREntityRelationships::DIAGRAM
    expect(parsed.entities).to eq(ruby.entities)
    expect(parsed.relationships).to eq(ruby.relationships)
    expect(parsed.to_svg(id: 'stable')).to eq(ruby.to_svg(id: 'stable'))
  end

  it 'strictly rejects unknown, null, malformed, and cross-type JSON' do
    source = {
      type: 'er', title: 'ER',
      entities: [
        { id: 'a', label: 'A', fields: [{ id: 'id', label: 'id' }] },
        { id: 'b', label: 'B', fields: [{ id: 'id', label: 'id' }] }
      ],
      relationships: [{ from: 'a', to: 'b', from_cardinality: '1', to_cardinality: 'N' }]
    }
    mutations = [
      ->(d) { d[:nodes] = [] }, ->(d) { d[:entities][0][:focal] = nil },
      ->(d) { d[:entities][0][:fields][0][:key] = nil }, ->(d) { d[:relationships][0][:label] = nil },
      ->(d) { d[:relationships][0][:from_cardinality] = 1 }, ->(d) { d[:entities][0][:extra] = true }
    ]
    mutations.each do |mutation|
      data = Marshal.load(Marshal.dump(source)); mutation.call(data)
      expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error)
    end
  end

  it 'renders every cardinality at its authored endpoint, natural heights, keys, masks, neutral paths, and separated ports' do
    diagram = SlimGraphR.diagram(:er) do
      entity(:a, 'A') { field :id, 'id', key: :primary }
      entity(:b, 'B') { field :id, 'id'; field :a_id, 'a_id', key: :foreign }
      entity(:c, 'C') { field :id, 'id'; field :note, 'note'; field :more, 'more' }
      relationship :a, :b, from: '1', to: 'N'
      relationship :a, :c, from: '0..1', to: '0..*'
      relationship :b, :c, from: '1..*', to: '1'
    end
    svg = diagram.to_svg(id: 'geometry')
    doc = REXML::Document.new(svg)
    expect(svg).to include('data-er="true"', '>#</text>', '>→</text>')
    expect(svg).not_to include('<marker', 'marker-end=')
    expect(svg.scan(/data-er-cardinality="([^"]+)"/).flatten).to eq(%w[1 N 0..1 0..* 1..* 1])
    heights = REXML::XPath.match(doc, "//*[@data-er-entity and @height and not(@data-er-cardinality-mask)]").to_h { |e| [e.attributes['data-er-entity'], e.attributes['height'].to_f] }
    expect(heights.values.uniq.size).to be > 1
    paths = REXML::XPath.match(doc, "//*[@data-er-relationship]")
    expect(paths).to all(satisfy { |p| p.attributes['d'] !~ /[CAST]/ && !p.attributes['marker-end'] })
    ports = REXML::XPath.match(doc, "//*[@data-er-port]").map { |p| [p.attributes['data-er-entity'], p.attributes['data-er-side'], p.attributes['data-er-coordinate'].to_f] }
    ports.group_by { |x| x[0, 2] }.each_value do |items|
      items.combination(2) { |a, b| expect((a[2] - b[2]).abs).to be >= 12 }
    end
    expect(REXML::XPath.match(doc, "//*[@data-er-cardinality-mask]").size).to eq(6)
    expect(REXML::XPath.match(doc, "//*[@data-er-label-mask]").size).to eq(0)
    REXML::XPath.match(doc, "//*[@data-er-cardinality]").each do |cardinality|
      relationship = cardinality.attributes['data-er-relationship']
      endpoint = cardinality.attributes['data-er-endpoint']
      entity = cardinality.attributes['data-er-entity']
      port = REXML::XPath.match(doc, "//*[@data-er-port and @data-er-relationship='#{relationship}' and @data-er-entity='#{entity}']").first
      cx, cy = port.attributes['cx'].to_f, port.attributes['cy'].to_f
      ax, ay = cardinality.attributes['data-er-anchor-x'].to_f, cardinality.attributes['data-er-anchor-y'].to_f
      mask = REXML::XPath.first(doc, "//*[@data-er-cardinality-mask='#{endpoint}' and @data-er-relationship='#{relationship}']")
      expected = %w[left right].include?(port.attributes['data-er-side']) ? mask.attributes['width'].to_f / 2.0 + 8 : mask.attributes['height'].to_f / 2.0 + 8
      expect((ax - cx).abs + (ay - cy).abs).to be_within(0.01).of(expected), "#{relationship} #{endpoint} cardinality anchor"
    end
  end

  it 'keeps cardinalities on authored entities when a relationship runs right to left' do
    diagram = SlimGraphR.diagram(:er) do
      entity(:left, 'Left') { field :id, 'id' }
      entity(:right, 'Right') { field :id, 'id' }
      relationship :right, :left, from: '1..*', to: '0..1'
    end
    doc = REXML::Document.new(diagram.to_svg(id: 'reverse'))
    from = REXML::XPath.first(doc, "//*[@data-er-cardinality='1..*']")
    to = REXML::XPath.first(doc, "//*[@data-er-cardinality='0..1']")
    expect([from.attributes['data-er-endpoint'], from.attributes['data-er-entity']]).to eq(%w[from right])
    expect([to.attributes['data-er-endpoint'], to.attributes['data-er-entity']]).to eq(%w[to left])
    path = REXML::XPath.first(doc, "//*[@data-er-relationship='right:left']")
    expect(path.attributes['marker-end']).to be_nil
  end

  it 'keeps measured endpoint masks wholly outside cards and clear of the relationship label' do
    doc = REXML::Document.new(build.to_svg(id: 'mask-bounds'))
    entities = REXML::XPath.match(doc, "//*[@data-er-entity and @height and not(@data-er-cardinality-mask)]")
    source, target = entities
    masks = REXML::XPath.match(doc, "//*[@data-er-cardinality-mask]")
    from_mask, to_mask = masks
    label_mask = REXML::XPath.first(doc, "//*[@data-er-label-mask]")
    source_right = source.attributes['x'].to_f + source.attributes['width'].to_f
    target_left = target.attributes['x'].to_f
    from_left = from_mask.attributes['x'].to_f
    from_right = from_left + from_mask.attributes['width'].to_f
    to_left = to_mask.attributes['x'].to_f
    to_right = to_left + to_mask.attributes['width'].to_f
    label_left = label_mask.attributes['x'].to_f
    label_right = label_left + label_mask.attributes['width'].to_f
    expect(from_left - source_right).to be_between(6, 10)
    expect(target_left - to_right).to be_between(6, 10)
    expect(label_left - from_right).to be >= 6
    expect(to_left - label_right).to be >= 6
  end

  it 'uses generated descriptions, literal replacements, and all style/theme combinations' do
    generated = build.to_svg(id: 'generated')[/<desc[^>]*>(.*?)<\/desc>/, 1]
    expect(generated).to include('Customer', 'customer_id', 'primary', 'Order', 'foreign', '1 to 0..*', 'places', 'focal')
    custom = build(description: 'Exact author description').to_svg(id: 'custom')
    expect(custom[/<desc[^>]*>(.*?)<\/desc>/, 1]).to eq('Exact author description')
    SlimGraphR::Style.names.product(%i[light dark]).each do |style, theme|
      svg = build.with(style: style, theme: theme).to_svg(id: "#{style}-#{theme}")
      expect(svg).to include("data-sgr-style=\"#{style}\"", "data-sgr-theme=\"#{theme}\"")
      REXML::Document.new(svg)
    end
  end

  it 'raises actionable errors rather than clipping or repairing unplaceable text and routes' do
    expect do
      SlimGraphR.diagram(:er) do
        entity(:a, 'A' * 100) { field :id, 'id' }
        entity(:b, 'B') { field :id, 'id' }
        relationship :a, :b, from: '1', to: 'N'
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /shorten|split/i)
    expect do
      SlimGraphR.diagram(:er) do
        entity(:a, 'A') { field :id, 'x' * 300 }
        entity(:b, 'B') { field :id, 'id' }
        relationship :a, :b, from: '1', to: 'N', label: 'y' * 300
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /shorten|split/i)
  end

  it 'keeps authored field type and qualifier separate and renders aggregate-root and join-table kinds' do
    diagram = SlimGraphR.diagram(:er) do
      entity :article, 'Article', kind: :aggregate_root, focal: true do
        field :id, 'id', key: :primary, type: 'uuid'
        field :slug, 'slug', type: 'text', qualifier: 'unique'
      end
      entity :article_tag, 'ArticleTag', kind: :join_table do
        field :article_id, 'article_id', key: :foreign, type: 'uuid'
      end
      relationship :article, :article_tag, from: '1', to: 'N'
    end
    article = diagram.entities.first
    expect([article.kind, article.fields.last.label, article.fields.last.type, article.fields.last.qualifier]).to eq(
      [:aggregate_root, 'slug', 'text', 'unique']
    )
    svg = diagram.to_svg(id: 'er-kinds')
    expect(svg).to include('AGGREGATE ROOT', 'JOIN TABLE', 'slug text · unique', 'data-er-entity-kind="aggregate_root"')
    expect(svg).to include('type text', 'qualifier unique', 'aggregate root', 'join table')
    json = {
      type: 'er', entities: [
        { id: 'article', label: 'Article', kind: 'aggregate_root', fields: [{ id: 'id', label: 'id', type: 'uuid' }] },
        { id: 'article_tag', label: 'ArticleTag', kind: 'join_table', fields: [{ id: 'article_id', label: 'article_id', qualifier: 'required' }] }
      ], relationships: [{ from: 'article', to: 'article_tag', from_cardinality: '1', to_cardinality: 'N' }]
    }
    parsed = SlimGraphR::Document.from_json(JSON.generate(json))
    expect(parsed.entities.map(&:kind)).to eq(%i[aggregate_root join_table])
    expect { SlimGraphR.diagram(:er) { entity(:a, 'A', kind: :table) { field :id, 'id' } } }.to raise_error(SlimGraphR::Error, /kind/)
  end
end
