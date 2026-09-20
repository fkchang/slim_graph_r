require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'database schema diagrams' do
  def schema(style: :editorial, theme: :light, &block)
    SlimGraphR.diagram(:db_schema, title: 'Checkout persistence', style: style, theme: theme, &block)
  end

  def representative
    schema do
      table :customers, 'customers', schema: 'public' do
        column :id, 'id', sql_type: 'uuid', constraints: [:pk]
        column :email, 'email', sql_type: 'text', constraints: %i[uq nn]
        index 'uq_customers_email'
      end
      table :orders, 'orders', schema: 'public' do
        column :id, 'id', sql_type: 'uuid', constraints: [:pk]
        column :customer_id, 'customer_id', sql_type: 'uuid', constraints: %i[fk nn]
        column :total_cents, 'total_cents', sql_type: 'integer', constraints: [:nn]
        index 'idx_orders_customer_id'
      end
      foreign_key :orders, :customer_id, references: %i[customers id], on_delete: :restrict
    end
  end

  it 'builds immutable literal table, column, index, and FK records with table-scoped column IDs' do
    model = representative
    expect(model.tables.map(&:id)).to eq(%w[customers orders])
    expect(model.tables.map { |t| t.columns.first.id }).to eq(%w[id id])
    expect(model.tables.last.columns[1].sql_type).to eq('uuid')
    expect(model.tables.last.columns[1].constraints).to eq(%i[fk nn])
    expect(model.tables.last.indexes).to eq(['idx_orders_customer_id'])
    expect(model.foreign_keys.first.on_delete).to eq(:restrict)
    expect(model).to be_frozen
    expect(model.tables).to be_frozen
    expect(model.tables.first.columns).to be_frozen
    expect(model.tables.first.columns.first.constraints).to be_frozen
  end

  it 'restores nested table scope after an error and replaces the generated description only when explicit' do
    expect do
      schema do
        begin
          table(:broken, 'broken') { column :id, 'id', sql_type: '', constraints: [:pk] }
        rescue SlimGraphR::Error
        end
        column :stray, 'stray', sql_type: 'text'
      end
    end.to raise_error(SlimGraphR::Error, /inside a table/)
    recovered = schema do
      begin
        table(:broken, 'broken') do
          column :id, 'id', sql_type: 'uuid', constraints: [:pk]
          raise 'stop'
        end
      rescue RuntimeError
      end
      table(:a, 'a') { column :id, 'id', sql_type: 'uuid', constraints: [:pk] }
      table(:b, 'b') { column :a_id, 'a_id', sql_type: 'uuid', constraints: [:fk] }
      foreign_key :b, :a_id, references: %i[a id], on_delete: :restrict
    end
    expect(recovered.tables.map(&:id)).to eq(%w[a b])
    expect(representative.to_svg(id: 'desc')).to include('Database schema diagram.', 'ON DELETE RESTRICT')
    custom = SlimGraphR.diagram(:db_schema, description: 'Exact custom description') do
      table(:a, 'a') { column :id, 'id', sql_type: 'uuid', constraints: [:pk] }
      table(:b, 'b') { column :a_id, 'a_id', sql_type: 'uuid', constraints: [:fk] }
      foreign_key :b, :a_id, references: %i[a id], on_delete: :no_action
    end
    expect(custom.to_svg(id: 'custom')).to include('<desc id="custom-desc">Exact custom description</desc>')
  end


  it 'routes around unrelated cards and does not group intervening tables into a shared schema' do
    model = schema do
      table(:source, 'source', schema: 'public') { column :target_id, 'target_id', sql_type: 'uuid', constraints: [:fk] }
      table(:middle, 'middle', schema: 'billing') { column :id, 'id', sql_type: 'uuid', constraints: [:pk] }
      table(:target, 'target', schema: 'public') { column :id, 'id', sql_type: 'uuid', constraints: [:pk] }
      foreign_key :source, :target_id, references: %i[target id], on_delete: :cascade
    end
    scene = model.layout
    middle = scene.boxes.find { |box| box.table.id == 'middle' }
    route = scene.routes.first
    route.points.each_cons(2) do |a, b|
      if a[1] == b[1]
        expect(a[1].between?(middle.y - 8, middle.y + middle.height + 8) &&
               [a[0], b[0]].min < middle.x + middle.width + 8 && [a[0], b[0]].max > middle.x - 8).to be(false)
      end
    end
    public_groups = scene.schema_groups.select { |group| group[:schema] == 'public' }
    expect(public_groups.map { |group| group[:members] }).to eq([['source'], ['target']])
    expect(route.label_box[:y]).to be < middle.y
  end

  it 'keeps shared-row routes distinct without an unmarked crossing near the target' do
    model = schema do
      table(:parent, 'parent') { column :id, 'id', sql_type: 'uuid', constraints: [:pk] }
      table(:near, 'near') { column :parent_id, 'parent_id', sql_type: 'uuid', constraints: [:fk] }
      table(:far, 'far') { column :parent_id, 'parent_id', sql_type: 'uuid', constraints: [:fk] }
      foreign_key :near, :parent_id, references: %i[parent id], on_delete: :restrict
      foreign_key :far, :parent_id, references: %i[parent id], on_delete: :cascade
    end
    routes = model.layout.routes
    expect(routes.map { |route| route.to_port[:point][1] }.sort.then { |a, b| b - a }).to eq(16)
    expect(routes.map { |route| route.to_port[:side] }.sort).to eq(%i[left right])
    expect { model.to_svg(id: 'separate-routes') }.not_to raise_error
  end

  it 'rejects missing, inferred, duplicate, unresolved, over-budget, and cross-type facts' do
    expect { schema { table(:a, 'a') { column :id, 'id' } } }.to raise_error(ArgumentError)
    expect { schema { table(:a, 'a') { column :id, 'id', sql_type: 'uuid', constraints: [:primary] } } }.to raise_error(SlimGraphR::Error, /constraints/)
    expect do
      schema do
        table(:a, 'a') { 2.times { column :id, 'id', sql_type: 'uuid' } }
        table(:b, 'b') { column :id, 'id', sql_type: 'uuid' }
      end
    end.to raise_error(SlimGraphR::Error, /unique within table/)
    expect do
      schema do
        table(:a, 'a') { column :id, 'id', sql_type: 'uuid', constraints: [:pk] }
        table(:b, 'b') { column :a_id, 'a_id', sql_type: 'uuid' }
        foreign_key :b, :a_id, references: %i[a id], on_delete: :cascade
      end
    end.to raise_error(SlimGraphR::Error, /source.*fk/i)
    expect do
      schema do
        table(:a, 'a') { column :id, 'id', sql_type: 'uuid' }
        table(:b, 'b') { column :a_id, 'a_id', sql_type: 'uuid', constraints: [:fk] }
        foreign_key :b, :a_id, references: %i[a id], on_delete: :cascade
      end
    end.to raise_error(SlimGraphR::Error, /target.*PK.*UQ/i)
    expect { schema { node :a } }.to raise_error(SlimGraphR::Error, /dedicated database-schema/)
  end

  it 'renders fixed 24px rows, exact row endpoints, symmetric shared-row ports, and rounded orthogonal paths' do
    model = schema do
      table :parents, 'parents' do
        column :id, 'id', sql_type: 'uuid', constraints: [:pk]
      end
      %i[left right].each do |id|
        table id, id.to_s do
          column :id, 'id', sql_type: 'uuid', constraints: [:pk]
          column :parent_id, 'parent_id', sql_type: 'uuid', constraints: [:fk]
        end
      end
      foreign_key :left, :parent_id, references: %i[parents id], on_delete: :restrict
      foreign_key :right, :parent_id, references: %i[parents id], on_delete: :set_null
    end
    scene = model.layout
    parent = scene.boxes.find { |b| b.table.id == 'parents' }
    ports = scene.routes.map(&:to_port).select { |p| p[:table] == 'parents' }.map { |p| p[:point][1] }.sort
    expect(parent.column_rows.first[:rect][3] - parent.column_rows.first[:rect][1]).to eq(24)
    expect(ports).to eq([parent.column_rows.first[:center_y] - 8, parent.column_rows.first[:center_y] + 8])
    expect(ports.each_cons(2).first.then { |a, b| b - a }).to be >= 12
    expect(scene.routes.flat_map(&:points).all? { |point| point.length == 2 }).to be(true)
    svg = model.to_svg(id: 'rows')
    expect(svg).to include('data-sgr-db-column="parents:id"', 'data-sgr-db-port="target"', ' Q ')
  end

  it 'renders schema names near 16px and every important metadata role at least 12px' do
    svg = representative.to_svg(id: 'readable-schema')
    root = svg[/<svg[^>]+>/]
    authored_width = root[/viewBox="0 0 ([\d.]+)/, 1].to_f
    display_width = root[/\bwidth="(\d+)"/, 1].to_f
    scale = display_width / authored_width

    expect(root).to include('data-sgr-display-scale="1.333"')
    expect(svg).to include('.sgr-db-table-name,#readable-schema .sgr-db-column-name{font-size:12px}',
                           '.sgr-db-sql-type,#readable-schema .sgr-db-index{fill:var(--sgr-muted);font-size:9px}',
                           '.sgr-db-constraint,#readable-schema .sgr-db-action{fill:var(--sgr-muted);font-size:9px')
    expect(SlimGraphR::Layout::DatabaseSchema::PRIMARY_TEXT_SIZE * scale).to be >= 16
    expect(SlimGraphR::Layout::DatabaseSchema::METADATA_TEXT_SIZE * scale).to be >= 12
  end

  it 'preserves reverse orientation and attaches both endpoints to named rows instead of table centers' do
    scene = schema do
      table(:child, 'child') do
        column :id, 'id', sql_type: 'uuid', constraints: [:pk]
        column :parent_id, 'parent_id', sql_type: 'uuid', constraints: [:fk]
      end
      table(:parent, 'parent') do
        column :label, 'label', sql_type: 'text'
        column :id, 'id', sql_type: 'uuid', constraints: [:uq]
      end
      foreign_key :child, :parent_id, references: %i[parent id], on_delete: :no_action
    end.layout
    route = scene.routes.first
    child = scene.boxes.find { |b| b.table.id == 'child' }
    parent = scene.boxes.find { |b| b.table.id == 'parent' }
    expect(route.from_port[:point][1]).to eq(child.column_rows[1][:center_y])
    expect(route.to_port[:point][1]).to eq(parent.column_rows[1][:center_y])
    expect(route.from_port[:point][1]).not_to eq(child.y + child.height / 2.0)
  end

  it 'renders every explicit delete action and accents all cascades plus their dependent table headers only' do
    model = schema do
      table(:parent, 'parent') { column :id, 'id', sql_type: 'uuid', constraints: [:pk] }
      { c1: :cascade, c2: :cascade, r: :restrict, n: :set_null }.each do |id, _action|
        table(id, id.to_s) { column :parent_id, 'parent_id', sql_type: 'uuid', constraints: [:fk] }
      end
      { c1: :cascade, c2: :cascade, r: :restrict, n: :set_null }.each do |id, action|
        foreign_key id, :parent_id, references: %i[parent id], on_delete: action
      end
    end
    svg = model.to_svg(id: 'actions')
    expect(svg.scan(/<text[^>]*>ON DELETE CASCADE<\/text>/).size).to eq(2)
    expect(svg).to include('ON DELETE RESTRICT', 'ON DELETE SET NULL')
    expect(svg.scan('data-sgr-db-cascade-header="true"').size).to eq(2)
    expect(svg).to include('data-sgr-db-table="c1"', 'data-sgr-db-table="c2"')
    expect(svg).not_to match(/data-sgr-db-table="parent"[^>]+data-sgr-db-cascade-header/)
    routes = model.layout.routes
    routes.combination(2) do |label_route, line_route|
      label = label_route.label_box
      expect(line_route.points.each_cons(2).any? do |a, b|
        left = label[:x] - label[:width] / 2.0 - 8
        right = label[:x] + label[:width] / 2.0 + 8
        top = label[:y] - label[:height] / 2.0 - 8
        bottom = label[:y] + label[:height] / 2.0 + 8
        a[0] == b[0] ? a[0].between?(left, right) && [a[1], b[1]].min < bottom && [a[1], b[1]].max > top :
          a[1].between?(top, bottom) && [a[0], b[0]].min < right && [a[0], b[0]].max > left
      end).to be(false)
    end
  end

  it 'strictly parses JSON and gives fixed-ID Ruby/JSON SVG parity in all styles and light/dark themes' do
    json = File.read(File.expand_path('../examples/standalone/database_schema.json', __dir__))
    load File.expand_path('../examples/standalone/database_schema.rb', __dir__)
    ruby_model = SlimGraphRDatabaseSchema::DIAGRAM
    json_model = SlimGraphR::Document.from_json(json)
    SlimGraphR::Style.names.product(%i[light dark]).each do |style, theme|
      expect(json_model.with(style: style, theme: theme).to_svg(id: 'parity')).to eq(
        ruby_model.with(style: style, theme: theme).to_svg(id: 'parity')
      )
    end
    parsed = JSON.parse(json)
    parsed['tables'][0]['columns'][0]['mystery'] = true
    expect { SlimGraphR::Document.from_json(JSON.generate(parsed)) }.to raise_error(SlimGraphR::Error, /Unknown/)
    parsed = JSON.parse(json)
    parsed['foreign_keys'][0].delete('on_delete')
    expect { SlimGraphR::Document.from_json(JSON.generate(parsed)) }.to raise_error(SlimGraphR::Error, /on_delete/)
    expect { SlimGraphR::Document.from_json(JSON.generate(JSON.parse(json).merge('nodes' => []))) }.to raise_error(SlimGraphR::Error, /cross-type/i)
    generic = { type: 'architecture', nodes: [{ id: 'a' }], tables: [] }
    expect { SlimGraphR::Document.from_json(JSON.generate(generic)) }.to raise_error(SlimGraphR::Error, /database-schema/)
  end

  it 'renders an explicit, bounded overflow-count row without inventing hidden columns' do
    model = schema do
      table(:products, 'products') do
        column :id, 'id', sql_type: 'uuid', constraints: [:pk]
        overflow_columns 3
      end
      table(:orders, 'orders') do
        column :id, 'id', sql_type: 'uuid', constraints: [:pk]
        column :product_id, 'product_id', sql_type: 'uuid', constraints: [:fk]
      end
      foreign_key :orders, :product_id, references: %i[products id], on_delete: :restrict
    end
    expect(model.tables.first.overflow.count).to eq(3)
    overflow = model.layout.boxes.first.overflow_row
    expect(overflow[:rect][3] - overflow[:rect][1]).to eq(24)
    expect(model.to_svg(id: 'overflow')).to include('+ 3 more columns', 'data-sgr-db-overflow-count="3"', 'explicitly omitted from this view')
    parsed = SlimGraphR::Document.from_json(JSON.generate(
      type: 'db_schema', tables: [
        { id: 'products', label: 'products', columns: [{ id: 'id', label: 'id', sql_type: 'uuid', constraints: ['pk'] }], overflow_columns: 3 },
        { id: 'orders', label: 'orders', columns: [{ id: 'product_id', label: 'product_id', sql_type: 'uuid', constraints: ['fk'] }] }
      ], foreign_keys: [{ from_table: 'orders', from_column: 'product_id', to_table: 'products', to_column: 'id', on_delete: 'restrict' }]
    ))
    expect(parsed.tables.first.overflow.count).to eq(3)
    expect { schema { table(:a, 'a') { overflow_columns 0 } } }.to raise_error(SlimGraphR::Error, /1 to 99/)
  end
end
