# Quadrant diagrams

Use `:quadrant` for a bounded 2×2 decision frame whose item positions are explicitly authored judgments. It works for impact/effort, reach/frequency, and positioning discussions. Use a quantitative chart when the coordinates are measured data, a Venn diagram for set overlap, or a consultant scenario matrix when each cell is a named future rather than a positioned point.

## Ruby

This is an ordinary Ruby file. It loads the dependency-free core, leaves the diagram as its final expression, and writes UTF-8 SVG when executed directly.

```ruby
# frozen_string_literal: true
require 'slim_graph_r'

DIAGRAM = SlimGraphR.diagram(:quadrant, title: 'Platform priorities · 優先順位') do
  horizontal_axis low: 'EASY', high: 'HARD'
  vertical_axis low: 'LOW IMPACT', high: 'HIGH IMPACT'
  item :cache, 'Cache migration', x: 0.72, y: 0.66, focal: true
  item :audit, 'Audit trail', x: -0.58, y: 0.34
  item :cleanup, 'Lint cleanup', x: -0.42, y: -0.46
  item :docs, 'Documentation', x: 0.35, y: -0.62
end

if $PROGRAM_NAME == __FILE__
  File.write(ARGV.fetch(0, 'quadrant.svg'), DIAGRAM.to_svg,
             mode: 'w', encoding: 'UTF-8')
end

DIAGRAM
```

Run the file normally with `ruby -Ilib examples/standalone/quadrant.rb quadrant.svg`, or use `ruby -Ilib exe/slimgraph render examples/standalone/quadrant.rb -o quadrant.html`.

## Strict JSON

The equivalent JSON keeps the same literal Unicode, axis phrases, source order, coordinates, and focal selection:

```json
{
  "type":"quadrant",
  "title":"Platform priorities · 優先順位",
  "horizontal_axis":{"low":"EASY","high":"HARD"},
  "vertical_axis":{"low":"LOW IMPACT","high":"HIGH IMPACT"},
  "items":[
    {"id":"cache","label":"Cache migration","x":0.72,"y":0.66,"focal":true},
    {"id":"audit","label":"Audit trail","x":-0.58,"y":0.34},
    {"id":"cleanup","label":"Lint cleanup","x":-0.42,"y":-0.46},
    {"id":"docs","label":"Documentation","x":0.35,"y":-0.62}
  ]
}
```

Parse JSON as plain data after `require 'slim_graph_r/document'`:

```ruby
diagram = SlimGraphR::Document.from_json(File.read('quadrant.json', encoding: 'UTF-8'))
```

The CLI accepts it directly: `ruby -Ilib exe/slimgraph render examples/standalone/quadrant.json -o quadrant.svg`.

## Meaning and geometry

`horizontal_axis` and `vertical_axis` each require literal nonblank `low:` and `high:` endpoint phrases. The renderer does not add arrows, “high/low” qualifiers, midpoint labels, units, or parentheticals to that copy. Every `item` requires a unique nonblank ID, a literal label, and real finite `x:` and `y:` coordinates in `[-1, 1]`. Coordinates whose absolute value is below `0.08` are rejected as an ambiguous central safety band; zero is invalid on either axis.

The 720×480 plot maps both coordinates linearly. It never snaps, jitters, ranks, scores, clusters, or moves a point to repair a collision. Two to twelve items are accepted. Zero or one item may set the strict boolean `focal: true`; this marks an author-selected discussion point and is not a recommendation inferred from its quadrant.

Optional `region :upper_left, 'DO FIRST'` declarations place literal labels in the four named corners (`:upper_left`, `:upper_right`, `:lower_left`, `:lower_right`). They are labels only: SlimGraphR never derives a region name from an axis or point position. JSON uses `"regions":[{"position":"upper_left","label":"DO FIRST"}]`.

Point labels are measured at their authored position. A candidate must remain wholly inside the same quadrant and clear the central axes, every dot, every placed label, and the plot boundary. When no candidate works, rendering raises `SlimGraphR::LayoutError` with advice to shorten a label, spread the authored positions, or split the quadrant. The visible and accessible caption always states: “Positions are qualitative author judgments, not calculated scores.”

Axis text uses the logical 8px metadata role and item/caption text uses 10px. The shared 1.5× readable display policy makes the physical minimum 12px and the base body 21px, above the 16px body floor. Narrow containers scroll horizontally rather than shrinking the complete geometry.

Descriptions, icons, custom colors, calculated priority, score import, automatic placement, clustering, filled cells, consultant scenario cells, and grids other than 2×2 are outside this bounded slice. Use `require 'slim_graph_r/stream_weaver'` only for the optional StreamWeaver adapter; the same `diagram :quadrant` block works in live canvas and exported HTML, while core Ruby and the packaged CLI have no StreamWeaver runtime dependency.

This is bounded partial parity with [Cathryn Lavery’s Diagram Design quadrant reference at revision `dcd9317ed9ec7477b20005544f36e3313664d815`](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-quadrant.md). SlimGraphR is an independent Ruby implementation; the pinned source and upstream MIT notice remain under `vendor/diagram-design`.
