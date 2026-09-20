# Wardley maps

Use `:wardley` to show a value chain against four qualitative stages of evolution. Use it to discuss what remains novel, what is becoming a product, and what has become a commodity. Use an architecture or data-flow diagram for runtime traffic and protocols, and a quantitative chart for measured values.

## Ruby

The Ruby DSL records every position and dependency explicitly:

```ruby
# frozen_string_literal: true
require 'slim_graph_r'

diagram = SlimGraphR.diagram(:wardley, title: 'Assistant value chain') do
  component :assistant, 'AI assistant', evolution: :genesis, visibility: 0.82
  component :orchestration, 'Agent orchestration', evolution: :custom_built, visibility: 0.58
  component :model_api, 'Model API', evolution: :product, visibility: 0.36, evolving_to: :commodity
  component :compute, 'Compute', evolution: :commodity, visibility: 0.14
  depends_on :assistant, :orchestration
  depends_on :orchestration, :model_api
  depends_on :model_api, :compute
end

File.write('wardley.svg', diagram.to_svg, mode: 'w', encoding: 'UTF-8')
```

Run the packaged example with `ruby -Ilib examples/standalone/wardley.rb wardley.svg`. The CLI can produce standalone SVG or HTML: `ruby -Ilib exe/slimgraph render examples/standalone/wardley.rb -o wardley.html`.

## Strict JSON

The equivalent JSON is plain validated data:

```json
{
  "type":"wardley",
  "title":"Assistant value chain",
  "components":[
    {"id":"assistant","label":"AI assistant","evolution":"genesis","visibility":0.82},
    {"id":"orchestration","label":"Agent orchestration","evolution":"custom_built","visibility":0.58},
    {"id":"model_api","label":"Model API","evolution":"product","visibility":0.36,"evolving_to":"commodity"},
    {"id":"compute","label":"Compute","evolution":"commodity","visibility":0.14}
  ],
  "dependencies":[
    {"from":"assistant","to":"orchestration"},
    {"from":"orchestration","to":"model_api"},
    {"from":"model_api","to":"compute"}
  ]
}
```

Load it with `SlimGraphR::Document.from_json`, after requiring `slim_graph_r/document`, or render it directly: `ruby -Ilib exe/slimgraph render examples/standalone/wardley.json -o wardley.svg`.

## Meaning and limits

Every component requires a unique nonblank ID, literal label, one of `genesis`, `custom_built`, `product`, or `commodity`, and a finite `visibility` in `[0,1]`. Visibility maps linearly: `1` is at the top, visible to the user, and `0` is at the bottom, invisible. X is the center of the named qualitative band. Neither axis has numeric ticks, scores, inferred positions, or calculated maturity.

`depends_on :a, :b` literally says A depends on B. It draws one straight muted line without an arrow and says nothing about runtime direction, protocol, or architecture. Two to nine components and one to twelve unique dependencies are accepted; every component must touch at least one dependency.

An optional `evolving_to:` must name the immediately adjacent band to the right. At most two components may move. Movement is a short dashed accent arrow; no label, timeframe, driver, color, icon, or leftward movement is accepted in this slice.

The measured plot has four equal bands, dashed separators, uppercase mono labels, stacked visibility endpoint words, and `r=6` component dots. Labels choose measured above, below, left, or right lanes while remaining in the authored qualitative band. Component, axis, caption, band, and legend text keep the shared 14px body / 12px metadata physical floor; the standard SVG is 1120px wide and grows with a wider container. Narrow containers retain the complete geometry and scroll horizontally. Direct dependencies remain straight; dependency and movement crossings use explicit bridges.

Dots never move to repair a collision. A dot, label, dependency, movement, axis, boundary, or legend interference that cannot use a measured label lane or crossing bridge raises `SlimGraphR::LayoutError` with advice to shorten labels, spread authored visibility values, or split the map. The visible caption and generated accessible description both state: “Band and visibility positions are qualitative author judgments, not calculated scores.” A supplied `description:` replaces the generated prose.

Free x/y, evolution scores, numeric ticks, inferred positions or dependencies, focal fields, dependency labels, movement labels, icons, custom colors, and architecture or runtime semantics are deferred.

This is bounded partial parity with [Cathryn Lavery’s Diagram Design Wardley reference at revision `dcd9317ed9ec7477b20005544f36e3313664d815`](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-wardley.md). SlimGraphR is an independent Ruby implementation; the pinned source and upstream MIT notice remain under `vendor/diagram-design`.
