# Database-schema diagrams

Database-schema diagrams show a physical relational subsystem: real table and column names, literal SQL types, explicit constraints, named indexes, and foreign keys attached to the exact source and target column rows. Use ER for conceptual domain entities and cardinality. A matching `*_id` name never creates a foreign key here.

The complete standalone Ruby example uses literal Unicode, writes the finished diagram when run directly, and leaves the final diagram as the file value:

```ruby
# frozen_string_literal: true
require 'slim_graph_r'

module SlimGraphRDatabaseSchema
  DIAGRAM = SlimGraphR.diagram(:db_schema, title: 'Checkout persistence · 注文') do
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

    foreign_key :orders, :customer_id,
                references: %i[customers id], on_delete: :restrict
  end
end

if $PROGRAM_NAME == __FILE__
  output = ARGV.fetch(0, 'database-schema.svg')
  File.write(output, SlimGraphRDatabaseSchema::DIAGRAM.to_svg, mode: 'w', encoding: 'UTF-8')
end

SlimGraphRDatabaseSchema::DIAGRAM
```

Run the Ruby file normally, or render it through the checkout CLI:

```sh
ruby -Ilib examples/standalone/database_schema.rb database-schema.svg
ruby -Ilib exe/slimgraph render examples/standalone/database_schema.rb -o database-schema.html
```

The equivalent strict JSON is data and can be read with plain `File.read`:

```json
{
  "type": "db_schema",
  "title": "Checkout persistence · 注文",
  "tables": [
    {
      "id": "customers",
      "label": "customers",
      "schema": "public",
      "columns": [
        {"id": "id", "label": "id", "sql_type": "uuid", "constraints": ["pk"]},
        {"id": "email", "label": "email", "sql_type": "text", "constraints": ["uq", "nn"]}
      ],
      "indexes": ["uq_customers_email"]
    },
    {
      "id": "orders",
      "label": "orders",
      "schema": "public",
      "columns": [
        {"id": "id", "label": "id", "sql_type": "uuid", "constraints": ["pk"]},
        {"id": "customer_id", "label": "customer_id", "sql_type": "uuid", "constraints": ["fk", "nn"]},
        {"id": "total_cents", "label": "total_cents", "sql_type": "integer", "constraints": ["nn"]}
      ],
      "indexes": ["idx_orders_customer_id"]
    }
  ],
  "foreign_keys": [
    {"from_table": "orders", "from_column": "customer_id", "to_table": "customers", "to_column": "id", "on_delete": "restrict"}
  ]
}
```

```ruby
require 'slim_graph_r/document'
json = File.read('examples/standalone/database_schema.json', encoding: 'UTF-8')
diagram = SlimGraphR::Document.from_json(json)
File.write('database-schema.svg', diagram.to_svg, mode: 'w', encoding: 'UTF-8')
```

The JSON CLI form is:

```sh
ruby -Ilib exe/slimgraph render examples/standalone/database_schema.json -o database-schema.svg
```

For StreamWeaver, explicitly load the optional adapter with `require 'slim_graph_r/stream_weaver'`, then use the same `diagram :db_schema` block. The inline SVG is static and remains usable in live canvas, canvas-read, and exported HTML.

A table owns 1–8 declaration-ordered visible columns and zero to three literal index names. `overflow_columns N` is optional and records one visible `+ N more columns` row for an explicit count from 1 through 99; it never invents those columns or permits a foreign key to target them. Column IDs are scoped to their table. Every concrete column requires a nonblank `sql_type:`. `constraints:` is a unique subset of `:pk`, `:fk`, `:uq`, and `:nn`; omission means that no constraint chip was declared. Optional `schema:` remains separate metadata, and only explicitly supplied schemas create dashed containment groups.

Every `foreign_key` names its source table and column, a literal destination pair, and `on_delete:` from `:cascade`, `:restrict`, `:set_null`, or `:no_action`. The source column must explicitly carry `:fk`; the target must explicitly carry `:pk` or `:uq`. The model never adds a chip, uniqueness, nullability, an index, an endpoint, or a deletion action.

Foreign-key lines attach to the vertical center of the declared 24px column rows. Multiple lines on one row use symmetric in-row ports; routes remain orthogonal with rounded 8px elbows. Every action has a masked label. Each authored cascade uses accent treatment and tints the header of its dependent source table, because those are the rows deleted; referenced parent tables and all other actions remain neutral. Multiple cascades remain visible.

Table and column names use a 12-unit primary role; schema labels, table/index tags, SQL types, constraints, index names, and deletion actions use one measured 9-unit metadata role. The schema's 4/3 physical display scale renders those roles at 16px and 12px without changing their measured relationships. Narrow hosts scroll the complete diagram at that readable size.

The bounded release accepts 2–5 tables, 1–8 visible concrete columns per table, zero or one explicit overflow count (1–99), 0–3 named indexes per table, and 1–6 foreign keys. Generated DDL, dialect validation, composite keys, checks/defaults/generated columns, views, triggers, index definitions, schema nesting, migration diffs, database dumps, arbitrary colors, and alternate actions are outside this release. Text, chips, cards, masks, schema groups, row ports, action labels, paths, or crossings that cannot remain readable raise `SlimGraphR::LayoutError`; shorten the content or split the subsystem.

This is bounded partial parity with [Cathryn Lavery’s Diagram Design database-schema reference at revision `dcd9317ed9ec7477b20005544f36e3313664d815`](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-db-schema.md). SlimGraphR is an independent Ruby implementation; the upstream MIT notice remains in `vendor/diagram-design`.
