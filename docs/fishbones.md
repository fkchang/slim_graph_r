# Fishbone diagrams

Fishbone diagrams organize investigated factors around one observed effect. Categories and factors are literal authored evidence. A category can optionally declare `confirmed: true` once evidence establishes it as the confirmed root category; SlimGraphR never infers that claim.

## Ruby

Save this as `fishbone.rb` and run it as a normal Ruby file:

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram(:fishbone, title: 'Checkout latency investigation · 調査') do
  effect 'Checkout p99 latency above 2 s'
  category :data, 'Data', side: :above do
    factor 'Missing index'
    factor 'Replica lag'
  end
  category(:deployment, 'Deployment', side: :below) { factor 'Cold workers' }
  category(:observability, 'Observability', side: :above) { factor 'No query breakdown' }
end

File.write('fishbone.svg', diagram.to_svg)
diagram
```

```sh
ruby -Ilib fishbone.rb
```

The checkout CLI accepts a Ruby document whose final expression is the diagram:

```sh
ruby -Ilib exe/slimgraph render fishbone.rb --output fishbone.svg
```

## Strict JSON

The equivalent JSON preserves Unicode, category order, side, and factor order:

```json
{
  "type": "fishbone",
  "title": "Checkout latency investigation · 調査",
  "effect": {"label": "Checkout p99 latency above 2 s"},
  "categories": [
    {"id": "data", "label": "Data", "side": "above", "factors": ["Missing index", "Replica lag"]},
    {"id": "deployment", "label": "Deployment", "side": "below", "factors": ["Cold workers"]},
    {"id": "observability", "label": "Observability", "side": "above", "factors": ["No query breakdown"]}
  ]
}
```

Read JSON as data; do not evaluate it as Ruby:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('fishbone.json'))
File.write('fishbone.svg', diagram.to_svg)
```

Or render it through the checkout CLI:

```sh
ruby -Ilib exe/slimgraph render fishbone.json --output fishbone.svg
```

Ruby and JSON build the same immutable model and produce byte-identical SVG when `to_svg` receives the same fixed `id:`.

## Optional StreamWeaver

StreamWeaver remains optional and is not loaded by `require 'slim_graph_r'`:

```ruby
require 'slim_graph_r/stream_weaver'

diagram :fishbone, title: 'Checkout latency investigation' do
  effect 'Checkout p99 latency above 2 s'
  category(:data, 'Data', side: :above) { factor 'Missing index'; factor 'Replica lag' }
  category(:deployment, 'Deployment', side: :below) { factor 'Cold workers' }
end
```

## Contract and layout limits

- Declare exactly one nonblank observed effect.
- Declare 2–5 categories with unique IDs, including at least one `:above` and one `:below`.
- A side accepts at most three categories. Source order is retained within each side's fixed slots.
- Each category requires 1–3 ordered, nonblank factor strings. The total factor budget is 18.
- Zero or one category may set `confirmed: true`. Its bone and tag, plus the effect head, receive the explicit accent and the generated description repeats the confirmed-root claim. All unconfirmed categories remain investigated leads.
- Category bones use the type's exact 60-degree exception. Factor ticks are 32px horizontal lines. Other diagram leaders remain governed by the shared orthogonal rule.
- A third lower category widens the logical scene and moves the head by the same 160px, keeping the left category and right effect inside the viewBox.
- Labels are measured before drawing. Content that cannot clear the viewBox or another label raises `SlimGraphR::LayoutError` with advice to shorten, split, or widen.

Fishbone is for associated leads around one observation. Use a timeline or sequence diagram for chronology, and record a conclusion outside this diagram after evidence establishes one. Generated descriptions repeat that the shown factors do not prove causation.

This bounded partial implementation follows the pinned fishbone grammar in [Cathryn Lavery's Diagram Design reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-fishbone.md), under the upstream MIT attribution retained in `vendor/diagram-design`. The stricter SlimGraphR contract intentionally omits the reference's confirmed-root-cause accent semantics.
