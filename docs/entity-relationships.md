# Entity-relationship diagrams

Entity-relationship diagrams answer one question: which domain entities relate, and what cardinality did the author declare at each end? They are conceptual or logical models. A field named `customer_id` does not create a relationship, infer a key, name a physical table, or imply SQL or deletion behavior.

The complete standalone Ruby example uses literal Unicode, writes the finished diagram when run directly, and leaves the final diagram as the file value:

```ruby
# frozen_string_literal: true
require 'slim_graph_r'

module SlimGraphREntityRelationships
  DIAGRAM = SlimGraphR.diagram(:er, title: 'Order domain · 注文') do
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

if $PROGRAM_NAME == __FILE__
  output = ARGV.fetch(0, 'entity-relationships.svg')
  File.write(output, SlimGraphREntityRelationships::DIAGRAM.to_svg, mode: 'w', encoding: 'UTF-8')
end

SlimGraphREntityRelationships::DIAGRAM
```

Run that Ruby file directly, or render it through the actual checkout CLI:

```sh
ruby -Ilib examples/standalone/entity_relationships.rb entity-relationships.svg
ruby -Ilib exe/slimgraph render examples/standalone/entity_relationships.rb -o entity-relationships.html
```

The equivalent strict JSON is data and can be read with plain `File.read`:

```json
{
  "type": "er",
  "title": "Order domain · 注文",
  "entities": [
    {"id": "customer", "label": "Customer", "fields": [
      {"id": "customer_id", "label": "customer_id", "key": "primary"},
      {"id": "email", "label": "email"}
    ]},
    {"id": "order", "label": "Order", "focal": true, "fields": [
      {"id": "order_id", "label": "order_id", "key": "primary"},
      {"id": "customer_id", "label": "customer_id", "key": "foreign"},
      {"id": "placed_at", "label": "placed_at"}
    ]}
  ],
  "relationships": [
    {"from": "customer", "to": "order", "from_cardinality": "1", "to_cardinality": "0..*", "label": "places"}
  ]
}
```

```ruby
require 'slim_graph_r/document'
json = File.read('examples/standalone/entity_relationships.json', encoding: 'UTF-8')
diagram = SlimGraphR::Document.from_json(json)
File.write('entity-relationships.svg', diagram.to_svg, mode: 'w', encoding: 'UTF-8')
```

The JSON CLI form is:

```sh
ruby -Ilib exe/slimgraph render examples/standalone/entity_relationships.json -o entity-relationships.svg
```

For StreamWeaver, explicitly load the optional adapter with `require 'slim_graph_r/stream_weaver'`, then use the same `diagram :er` block. The generated SVG is static and remains usable in live canvas, canvas-read, and exported HTML.

An entity owns one to eight declaration-ordered fields. `kind:` is optional and literal: `:entity` is the default, while `:aggregate_root` and `:join_table` label the conceptual role without creating physical database behavior. Field IDs are unique only inside that entity, so the same `customer_id` can appear in both entities. A field may separately declare literal `type:` and `qualifier:` text; neither value infers a key, relationship, table, SQL constraint, or foreign key. `key: :primary` renders `#`; `key: :foreign` renders `→`; omission renders no key glyph.

A relationship requires distinct declared entities and exact `from:` and `to:` cardinalities from `1`, `N`, `0..1`, `0..*`, or `1..*`. The token stays with its authored endpoint even when the route runs right to left. Relationships are neutral and have no direction arrow. An optional label is literal.

The bounded release accepts 2–6 entities, 1–8 visible fields per entity, 1–8 relationships, and zero or one focal entity. Cards retain natural height from their actual fields. The field `type:` is conceptual annotation, not a physical SQL schema; use database-schema diagrams for tables, SQL constraints, indexes, and foreign keys. Self-relationships, deletion actions, crow’s-foot glyphs, schema containment, subtype inheritance, custom colors, coordinates, generic nodes/edges/groups, and inferred relationships are outside this release. Text, ports, routes, masks, labels, or crossings that cannot fit clearly raise `SlimGraphR::LayoutError`; shorten labels or split the model.

This is bounded partial parity with [Cathryn Lavery’s Diagram Design ER reference at revision `dcd9317ed9ec7477b20005544f36e3313664d815`](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-er.md). SlimGraphR is an independent Ruby implementation; the upstream MIT notice remains in `vendor/diagram-design`.
