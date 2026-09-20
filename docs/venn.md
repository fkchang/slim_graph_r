# Venn diagrams

Use `:venn` to name the complete overlap topology of two or three comparable conceptual sets. It suits “where A meets B” and three-part product-fit discussions. Use a matrix for four or more sets and a quantitative chart when area, population, counts, weights, or percentages matter.

## Ruby

This is an ordinary Ruby file. It loads the dependency-free core, leaves the diagram as its final expression, and writes UTF-8 SVG when executed directly.

```ruby
# frozen_string_literal: true
require 'slim_graph_r'

diagram = SlimGraphR.diagram(:venn, title: 'Product fit · 適合') do
  set :desirable, 'Desirable'
  set :feasible, 'Feasible'
  set :viable, 'Viable'
  intersection [:desirable, :feasible], 'Useful'
  intersection [:desirable, :viable], 'Wanted'
  intersection [:feasible, :viable], 'Sustainable'
  intersection [:desirable, :feasible, :viable], 'Product fit', focal: true
end

if $PROGRAM_NAME == __FILE__
  File.write(ARGV.fetch(0, 'venn.svg'), diagram.to_svg,
             mode: 'w', encoding: 'UTF-8')
end

diagram
```

Run it normally with `ruby -Ilib examples/standalone/venn.rb venn.svg`. The real checkout CLI accepts the same file: `ruby -Ilib exe/slimgraph render examples/standalone/venn.rb -o venn.html`.

## Equivalent strict JSON

The equivalent JSON preserves every set, intersection, member order, literal Unicode label, and focal choice:

```json
{
  "type":"venn",
  "title":"Product fit · 適合",
  "sets":[
    {"id":"desirable","label":"Desirable"},
    {"id":"feasible","label":"Feasible"},
    {"id":"viable","label":"Viable"}
  ],
  "intersections":[
    {"sets":["desirable","feasible"],"label":"Useful"},
    {"sets":["desirable","viable"],"label":"Wanted"},
    {"sets":["feasible","viable"],"label":"Sustainable"},
    {"sets":["desirable","feasible","viable"],"label":"Product fit","focal":true}
  ]
}
```

Parse the file as plain data after loading the document reader:

```ruby
require 'slim_graph_r/document'
diagram = SlimGraphR::Document.from_json(File.read('venn.json', encoding: 'UTF-8'))
```

The CLI reads it directly with `ruby -Ilib exe/slimgraph render examples/standalone/venn.json -o venn.svg`.

## Complete named topology

`set` requires a unique nonblank ID and a literal nonblank label. An optional literal `subtitle:` is rendered directly below that set label and is not inferred from any overlap. A Venn diagram has exactly two or three sets. `intersection` receives a declaration-ordered array of two or three distinct existing set IDs and a literal region label. For two sets, declare the sole pair. For three sets, declare all three pairs and the triple exactly once. This rule ensures every visible overlap has a name.

Member order remains as authored in the model and generated description. The validator sorts a temporary copy only to detect duplicate topology, so `[:a, :b]` and `[:b, :a]` are duplicates without rewriting the first declaration.

Zero or one intersection may set the strict boolean `focal: true`. Focal means the author selected that overlap for discussion. The renderer does not calculate a sweet spot or recommend it.

## Fixed topology geometry

The two-set template uses equal circles with radius 224px and centers 272px apart. The three-set template uses equal radius-192px circles on a fixed 4px-grid triangle. These templates encode topology only. Circle area, overlap area, and visual population are not quantitative and must not be read as counts, weights, proportions, likelihood, or importance.

Every set label is measured in a fixed region outside its circle. Every pair/triple label is measured in a clear fixed region that belongs to exactly those named circles. A focal intersection receives one accent-tint region clipped to its authored member circles and an accent label. Low-opacity set tints compound in overlaps across all four styles and light/dark/auto themes.

The renderer never resizes or repositions circles, moves labels into a different semantic region, changes membership, drops an overlap, or discovers intersections. A label that cannot remain within its fixed region while clearing strokes and other labels raises `SlimGraphR::LayoutError` with advice to shorten the label or split the diagram.

Set labels use a logical 16px role and intersection labels use 12px. Venn registers a 12px meaningful minimum; the shared readable display policy yields a physical minimum of 16px and keeps base body copy at 16px or larger. Narrow containers scroll horizontally rather than distorting or shrinking the circles.

## Strict boundaries

The JSON root accepts only `type`, `title`, `description`, `style`, `theme`, `sets`, and `intersections`. A set accepts only `id` and `label`. An intersection accepts only `sets`, `label`, and optional boolean `focal`. Optional fields are omitted, never `null`. Wrong types, unknown keys, blank text, duplicate IDs or topology, repeated members, missing member references, incomplete topology, and more than one focal overlap fail.

Weights, counts, percentages, sizes, radii, positions, coordinates, custom colors, per-set colors, omitted regions, automatic discovery, Euler geometry, four or more sets, leaders, and quantitative area fitting are outside this bounded slice. A future quantitative-area type would need its own semantics. Use `require 'slim_graph_r/stream_weaver'` only for the optional adapter; the same `diagram :venn` block works there while the core and packaged CLI have no StreamWeaver runtime dependency.

This is bounded partial parity with [Cathryn Lavery’s Diagram Design Venn reference at revision `dcd9317ed9ec7477b20005544f36e3313664d815`](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-venn.md). SlimGraphR is an independent Ruby implementation; the pinned source and upstream MIT notice remain under `vendor/diagram-design`.
