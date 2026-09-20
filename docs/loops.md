# Loop diagrams

Use `:loop` for a bounded clockwise operating cycle whose stations all write explicitly to one shared state hub. The cycle and write-backs are separate claims: `cycle` declares every adjacent station-to-station arc, including the last-to-first closure, while each `write_back` declares a station-to-hub relation.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram(:loop, title: 'Self-improving loop · 自己改善', direction: :clockwise) do
  hub :memory, 'Shared memory', sublabel: 'one record, every loop'
  station :capture, 'Capture', sublabel: 'signals in'
  station :research, 'Research', sublabel: 'evidence pulled'
  station :decide, 'Decide', sublabel: 'human approves', focal: true
  station :act, 'Act', sublabel: 'work ships'
  station :measure, 'Measure', sublabel: 'outcomes logged'
  cycle :capture, :research, :decide, :act, :measure
  write_back :capture, to: :memory, label: 'SIGNALS'
  write_back [:research, :decide, :measure], to: :memory
  write_back :act, to: :memory, label: 'OUTCOMES'
end

File.write('loop.svg', diagram.to_svg)
```

The list form of `write_back` is only shorthand for several explicit relations. It expands the listed station IDs and never creates a spoke for an omitted station. Labels are optional literal annotations; an unlabeled write-back still remains an authored relation.

The equivalent strict JSON is:

```json
{
  "type":"loop", "title":"Self-improving loop · 自己改善", "direction":"clockwise",
  "hub":{"id":"memory","label":"Shared memory","sublabel":"one record, every loop"},
  "stations":[
    {"id":"capture","label":"Capture","sublabel":"signals in"},
    {"id":"research","label":"Research","sublabel":"evidence pulled"},
    {"id":"decide","label":"Decide","sublabel":"human approves","focal":true},
    {"id":"act","label":"Act","sublabel":"work ships"},
    {"id":"measure","label":"Measure","sublabel":"outcomes logged"}
  ],
  "cycle":["capture","research","decide","act","measure"],
  "write_backs":[
    {"from":"capture","to":"memory","label":"SIGNALS"},
    {"from":"research","to":"memory"},
    {"from":"decide","to":"memory"},
    {"from":"act","to":"memory","label":"OUTCOMES"},
    {"from":"measure","to":"memory"}
  ]
}
```

Run the standalone Ruby file normally:

```sh
ruby -Ilib examples/standalone/loop.rb
```

Render either authoring form with the checkout CLI:

```sh
ruby -Ilib exe/slimgraph render examples/standalone/loop.rb --output loop-ruby.svg
ruby -Ilib exe/slimgraph render examples/standalone/loop.json --output loop-json.svg
```

JSON remains plain UTF-8 data and can be loaded without evaluation:

```ruby
require 'slim_graph_r/document'

source = File.read('examples/standalone/loop.json', encoding: 'UTF-8')
diagram = SlimGraphR::Document.from_json(source)
File.write('loop.svg', diagram.to_svg)
```

Optional StreamWeaver use starts with `require 'slim_graph_r/stream_weaver'` and uses the same `diagram :loop` block. The core gem has no StreamWeaver runtime dependency.

## Semantics and limits

- `direction: :clockwise` is required. Counterclockwise direction is outside this slice.
- Declare exactly one hub and five to eight uniquely identified stations.
- `cycle` is mandatory and names every station exactly once. Its first ID is shown at −90°, and following IDs advance at equal clockwise angles in that authored order. Station declaration order does not supply or repair the cycle.
- The cycle verb explicitly authorizes every adjacent arc and the final-to-first closure. There is no implicit closing edge.
- Every station must have exactly one declared write-back whose destination is the hub. Missing, duplicate, unknown, or alternate destinations fail rather than producing inferred spokes.
- Zero or one station may set `focal: true`. Focal means an author-selected operating gate. The dark central hub means shared accumulated state; it is not an extra process step.
- Skipped stations, branches, multiple cycles or hubs, custom coordinates/radii/paths, and non-boolean focal values are rejected. Use a flowchart for branching decisions, a state machine for lifecycle transitions, or a sequence diagram when ordered interactions matter more than accumulated shared state.

Stations use measured 160–208×64 cards: the shared station width expands in
4px increments for the widest literal label or sublabel, while the hub remains
200×104 and the type owns a 240px ring radius. True circular SVG arcs follow
that radius clockwise and stop clear of station cards. Dashed radial
write-backs start at station edges and stop 6px before the hub edge. The
renderer keeps the authored topology fixed; text that cannot fit raises
`SlimGraphR::LayoutError` with shorten-or-split guidance. The shared display
policy keeps meaningful text at a physical minimum of 12px and preserves
horizontal scrolling on narrow hosts.

This is a bounded partial-parity slice, not full upstream parity. Its semantic and visual lineage is Cathryn Lavery’s pinned [Diagram Design loop reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-loop.md). The executable [Ruby](../examples/standalone/loop.rb), [JSON](../examples/standalone/loop.json), and [StreamWeaver](../examples/stream_weaver/loops.rb) examples are the local contracts.
