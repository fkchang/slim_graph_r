# SlimGraphR

![A small Ruby drafting press turns a compact description into a clear picture](assets/concepts/ruby-press-v1.png)

**Express intention. Get the picture.**

You wanted to explain how a few things connect. Somehow you're negotiating with arrowheads, nudging boxes, and asking an AI to recalculate coordinates because you changed a label.

That's a ridiculous amount of ceremony for **“this connects to that.”**

Ruby has a better habit: let the code look like the thought.

```ruby
require 'slim_graph_r'

picture = SlimGraphR.diagram :architecture,
  title: 'Express intention. Get the picture.', style: :ruby do
  external :intent, 'Your intent', detail: 'Parts and relationships'
  node :ruby, 'A little Ruby', emphasis: true, detail: 'Layout, labels and connectors'
  node :svg, 'A clear diagram', detail: 'Portable SVG'
  flow :intent, :ruby, :svg
end

File.write('picture.svg', picture.to_svg)
```

![Actual SlimGraphR output from the example above](examples/rendered/architecture.svg)

**Say what matters. Let Ruby do the fussy work.**

SlimGraphR turns an expressive Ruby description into an editorial SVG. It places the nodes, wraps the labels, routes the connections, and gives the result a visual language. You keep your attention on what the picture means.

That is also why it works well for agents. The model describes intent; deterministic code does the drawing. A smaller authoring surface means fewer tokens spent spelling out the machinery. The [benchmark](docs/benchmark.md) shows what we've measured—and exactly what we haven't.

Inspired by **[Cathryn Lavery's Diagram Design](https://github.com/cathrynlavery/diagram-design)**. This is our independent Ruby take on its editorial ambition: a compact DSL, a real renderer, and a path toward full parity. The hero above is generated artwork; the SVG below it is actual library output.

## Get a picture on screen

From this checkout—this version is not yet published to RubyGems:

```sh
gem build slim_graph_r.gemspec
gem install ./tmp/slim_graph_r-0.30.0.gem --no-document

slimgraph render examples/standalone/publishing.rb -o publishing.html
```

Open `publishing.html` in your browser. The core renderer needs Ruby 3.1+ and has no runtime gem dependencies. No layout service, API key, browser engine, or StreamWeaver installation is needed to render.

Already in a Ruby project? Add a path dependency while developing:

```ruby
gem 'slim_graph_r', path: '../slim_graph_r'
```

## A small vocabulary that earns its keep

```ruby
step :draft
decision :review, 'Ready to publish?', emphasis: true
step :publish
step :revise

flow :draft, :review
edge :review, :publish, 'Approved'
edge :review, :revise, 'Needs changes'
```

`flow` handles a chain. `edge` says something specific about a connection. IDs become readable names, so `node :background_worker` already knows what to put in the box. Give it an explicit label when the wording matters. Typos in references fail loudly.

Thirty-one diagram types ship today:

| Type | Tell it about |
| --- | --- |
| Architecture | Components, groups, stores, and external systems |
| Flowchart | Start/end shapes, decisions, branches, and explicit merge points |
| Sequence | Calls, replies, activations, alternatives, optional work, and loops |
| Timeline | Honest elapsed spacing for parseable dates, or explicit ordered milestones |
| Org chart | Teams, owners, and reporting relationships |
| State machine | Lifecycle states, entry/final markers, and named transitions |
| Dependency graph | Shared dependencies, package origins, fan-in, and one real cycle |
| Deployment | Zones, infrastructure nodes, replicas, versioned artifacts, and network paths |
| IT current-state | Phased systems, current handoffs, pain points, and cross-cutting services |
| High-Level | End-to-end data stacks with sources, phases, orchestration, and cross-cutting concerns |
| Tree / Hierarchy | Branching ownership, taxonomy, and file-style hierarchies |
| Nested Containment | Scope boundaries and nested responsibility |
| Layer Stack | Ordered abstraction and context bands |
| Pyramid / Funnel | Ranked hierarchies and quantity-faithful conversion funnels |
| Medallion | Left-to-right storage tiers, promotions, concerns, and write paths |
| Swimlane | Actor lanes, numbered stages, activities, and explicit handoffs |
| Process | Actor lanes with tools, payload codes, focal stages, and return triggers |
| Gantt Chart | Calendar plans with phases, tasks, milestones, and static markers |
| Kanban Board | Ordered work-state columns, cards, states, metadata, and WIP limits |
| User Journey Map | One persona's ordered stages, ordinal sentiment, and a unique trough |
| User Story Map | One persona's narrative activities, release slices, cut, and risk |
| Data Flow | Role/stage transfers, declared payloads, and explicit handoffs |
| DP integration | Bounded platform zones, declared integration wires, and layer services |
| DP security matrix | Explicit role/component permissions, including authored denial and unknown cells |
| ER / Data Model | Conceptual entities, literal fields, and authored cardinality at both relationship ends |
| Database Schema | Physical tables, SQL types, explicit constraints and indexes, and row-level foreign keys |
| UML Class Diagram | Object types, literal members, and six explicit relationship kinds |
| Quadrant | Authored qualitative positions across two literal low/high axes |
| Venn / Set Overlap | Complete named topology for two or three comparable sets |
| Loop | Explicit clockwise station cycles with one shared-state hub |
| Fishbone | Investigated factors grouped around one observed effect |
| Wardley Map | Explicit qualitative evolution and visibility positions in a value chain |
| Bar | Signed one-series category comparisons from exact zero |
| Line | Straight shared-scale series over elapsed time or explicit ordinal positions |
| Scatter | Exact two-variable position on required finite linear scales |
| Polar | One ordered nonnegative series with exact linear rays and no wedges |
| Radar | Already-common scores with exact vertex radii and outline-only polygons |

Flowcharts now have `start`, `finish`, and `merge` helpers alongside `step` and `decision`. Decisions require labeled exits (at most three); a merge takes two or three inputs and one output. See the [full flowchart example](examples/standalone/flowchart.rb).

Sequences use `activate :service do ... end`, `alt` with two `branch` blocks, and guarded `opt`/`loop` blocks. `reply` and `notify` give responses and notifications distinct arrowheads. [See the sequence guide](docs/sequence.md).

All **39 upstream type names** now have bounded partial implementations. At 0.30.0, 39 are partial, 0 remain missing, and 0 are fully verified; we track the evidence in the [coverage matrix](docs/roadmap/parity-matrix.md). Named coverage is complete, but a type name in the API is not a claim that its entire upstream grammar or variants are implemented.

Bar, line, and scatter charts share a strict quantitative foundation: finite `Integer`, `Float`, or `BigDecimal` values; plain half-even labels; finite linear domains; exact zero and signed positions; and scale metadata in visible and accessible output. Bars never paint a zero rectangle. Lines space complete Gregorian dates by elapsed days, mark ordinal spacing explicitly, and disconnect at declared gaps. Scatter requires both units and both explicit scales and uses position alone. See the [bar](docs/bar-charts.md), [line](docs/line-charts.md), and [scatter](docs/scatter-plots.md) guides.

Treemap and Sankey extend the same numeric foundation with exact area and conservation. Treemaps preserve each positive share in one unsnapped rectangle while keeping zeros as data with no cell. Sankeys require exact three-stage balance and use one scale for every node and ribbon, including fractional values; a subpixel ribbon fails with an actionable remedy. See the [treemap](docs/treemaps.md) and [Sankey](docs/sankeys.md) guides.

Polar and Radar keep radial position quantitative without giving area a false meaning. Polar preserves authored category order at equal angles, draws exact value rays with constant markers, and omits the ray and marker for zero. Radar requires one already-common score and uses outline-only polygons with colour-independent stroke patterns. See the [polar](docs/polar-charts.md) and [radar](docs/radar-charts.md) guides.

Timelines use `scale: :date` for complete Gregorian dates (`YYYY-MM-DD`). Events sort chronologically and keep exact elapsed-day positions; same-day events share a marker and retain all their text. `scale: :ordered` preserves author order for captions such as “Next”; `:auto` chooses dates only when every value is valid. Dense inputs fail explicitly instead of distorting dates. [Timeline guide](docs/timeline.md).

Org charts keep ownership semantics explicit: `owner` names the accountable person or team, while `invoke:` records how to reach them and `scope:` records what they cover. `unavailable: true` keeps a missing owner visible and marks the setup gap. Escalations and approvals render in a separate footer strip rather than becoming reporting nodes. The [org-chart guide](docs/org-charts.md) includes equivalent standalone Ruby and strict JSON examples, limits, and validation behavior; the executable examples are [Ruby](examples/standalone/org_ownership.rb), [JSON](examples/standalone/org_ownership.json), and [StreamWeaver](examples/stream_weaver/org_charts.rb).

State machines use `state`, `initial`, `final`, and `transition` to describe a bounded lifecycle. Transition labels preserve `event [guard] / action`; recovery into the initial state is allowed, terminal states have no outgoing transitions, and dense routes may raise `LayoutError`. The [state-machine guide](docs/state-machines.md) includes equivalent Ruby/JSON input, StreamWeaver syntax, limits, and executable examples.

Dependency graphs use `dependency`, `external_dependency`, and `depends_on` to show where packages, modules, or services converge. Arrows point from dependent to requirement; every node gets a computed fan-in badge, and one marked real cycle may use an outside accent lane. The [dependency guide](docs/dependencies.md) covers standalone Ruby, strict JSON, the CLI, limits, and the tree-shaped-data boundary.

Deployment diagrams use `zone` containment, typed infrastructure constructors (`host`, `vm`, `pod`, `managed`, and `cdn`), versioned `artifact` chips, and protocol/port `network` paths. Replicas stay on one node with an `xN` badge; cross-zone and internal paths use distinct treatments, and async paths are dashed. The [deployment guide](docs/deployments.md) covers standalone Ruby, strict JSON, both CLI forms, optional StreamWeaver loading, limits, and faithful-layout errors. This is a bounded partial slice, not a full upstream parity claim.

IT current-state diagrams use horizontal `phase` blocks containing named `system`s, labelled `handoff`s, and optional `crosscut` services. Systems can be standard, external, or pain points; dashed handoffs use the file-transfer treatment and backward handoffs require an external endpoint. The [IT current-state guide](docs/it-current-state.md) covers Ruby, strict JSON, both CLI forms, optional StreamWeaver loading, limits, and faithful-layout errors. This is a bounded partial slice, not a full upstream parity claim.

High-level diagrams use a dedicated `:high_level` DSL for a compact end-to-end data stack: a first source phase, later component phases, forward interphase data links, one explicit focal component, an orchestration bar, and concern-paired crosscuts. The [high-level guide](docs/high-level.md) covers standalone Ruby, strict JSON, both CLI forms, optional StreamWeaver loading, limits, defaults, and faithful-layout errors. This is a bounded partial slice, not a full upstream parity claim.

Tree diagrams use nested `root` and `child` blocks with direct orthogonal sibling buses, optional details, and zero or one focal node. The [tree guide](docs/trees.md) covers strict recursive JSON, CLI forms, optional StreamWeaver loading, depth/breadth bounds, and faithful-layout errors. This is a bounded partial slice, not a full upstream parity claim.

Nested containment diagrams use one 3–5 scope chain with regular insets and automatic focus on the innermost scope. Layer stacks use 4–6 equal bands, required indices, one focal layer, an `Abstraction` axis by default, and an up/down indicator. See the [nested guide](docs/nested-containment.md) and [layer-stack guide](docs/layer-stacks.md) for strict JSON, CLI forms, optional StreamWeaver loading, limits, and faithful-layout errors. These are bounded partial slices, not complete upstream parity.

Pyramid diagrams separate ordinal hierarchy from measured funnels. Hierarchy uses a linear taper without a quantity claim; measured bands preserve exact proportional widths, equal-count plateaus, and zero tails, moving narrow labels to outside leaders without widening the encoded band. The [pyramid guide](docs/pyramids.md) covers both orientations, strict JSON, CLI/library forms, and faithful-layout errors. Medallion diagrams use 3–6 fixed storage cards, one focal tier, an optional final archive, adjacent promotion arcs, semantic concerns, and 0–2 write paths. The [medallion guide](docs/medallions.md) documents the matching Ruby/JSON model and fixed geometry. Swimlane diagrams use dedicated actor lanes, numbered stages, one activity per lane/stage cell, and explicit forward handoffs. Process diagrams add explicit lane keys, tools, payload codes, one focal stage and operation, and one optional labelled return trigger. The [swimlane guide](docs/swimlanes.md) and [process guide](docs/processes.md) cover strict JSON, both CLI forms, optional StreamWeaver loading, measured geometry, limits, and faithful-layout errors. Gantt diagrams use an author-supplied calendar plan with complete Gregorian dates, half-open task bars, declaration-order phase rows, exact milestone points, and static reference markers; see the [Gantt guide](docs/gantt.md). Kanban diagrams use an ordered work-state census with optional card metadata, neutral/default state, focal-ring emphasis, and honest WIP counts and violations; see the [Kanban guide](docs/kanban.md). User journeys keep one persona, declaration-ordered stages, explicit ordinal sentiments, a unique lowest trough, optional touchpoints, and trough-only pain markers; see the [journey guide](docs/journeys.md). Story maps keep one persona, narrative activity/step order, release bands, one non-final cut, authored estimate/ticket metadata, and at most one risk story; see the [story-map guide](docs/story-maps.md). Data-flow diagrams use role × stage grids with declared transfer payloads, explicit handoff kinds, and one linked focal claim; see the [data-flow guide](docs/data-flows.md). DP integration diagrams use a bounded platform zone and explicit wires; see the [platform-integration guide](docs/platform-integrations.md). DP security matrices require an explicit permission for every role/component pair and render no connectors; see the [access-matrix guide](docs/access-matrices.md). These are bounded partial slices, not complete upstream parity.

Entity-relationship diagrams use dedicated entities, conceptual fields, and neutral relationships with exact authored cardinalities at both ends. Entity kinds (`aggregate_root` and `join_table`) plus literal field type/qualifier annotations remain conceptual; matching field names never infer a connector or physical foreign key. See the [entity-relationship guide](docs/entity-relationships.md).

## Your kind of Ruby

Choose the visual treatment independently of light or dark mode:

```ruby
diagram :flowchart, style: :ruby, theme: :dark do
  # Same parts. Same relationships. Your presentation.
end
```

| Style | Character |
| --- | --- |
| `:editorial` | Serif titles, slate ink, restrained coral; the compatible default |
| `:ruby` | Warm ivory, deep red, confident sans-serif headings |
| `:blueprint` | Technical blue and monospaced display headings |
| `:mono` | Neutral ink and paper, with grayscale emphasis |

Each has light and dark palettes. `theme: :auto` follows OS/page mode. Fonts have local fallbacks; none are downloaded. Heading metrics participate in wrapping. The body text remains deliberately consistent across presets.

```sh
slimgraph render diagram.rb --style ruby --theme dark -o diagram.svg
slimgraph styles
```

## Ruby inside. Useful everywhere.

Use the gem in a script, Rails app, documentation build, or background job. Save SVG with `to_svg`, or a self-contained diagram page with `to_html`.

The CLI also accepts JSON, so agents and tools in other languages can use the same renderer:

```sh
slimgraph render examples/standalone/publishing.json -o publishing.svg
cat examples/standalone/publishing.json | slimgraph render - > publishing.svg
```

JSON is validated data. Local `.rb` inputs execute as Ruby code. Unknown fields, missing nodes and unsupported types produce clear errors. Existing output files are preserved unless you pass `--force`. See the [JSON contract](docs/json-input.md) and `slimgraph --help`.

## StreamWeaver feels right at home

```ruby
require 'slim_graph_r/stream_weaver'

diagram :architecture, style: :ruby do
  external :client
  node :api, 'API', emphasis: true
  store :database
  flow :client, :api, :database
end
```

That adds a real `diagram` component to StreamWeaver's shared DSL. It works in apps, live canvas, saved Ruby and Org documents, HTML exports, and StreamWeaver's offline Chrome viewer. The browser viewer compiles the narrow `slim_graph_r/stream_weaver_opal` entrypoint into its existing Opal runtime; it does not load StreamWeaver's server stack or fetch diagram assets. The adapter is optional; StreamWeaver users install both gems, and everyone else just uses SlimGraphR.

The [StreamWeaver examples](examples/stream_weaver/) live here alongside the [standalone examples](examples/standalone/). The renderer stays useful on its own. Other components in a StreamWeaver page may request their own assets; the diagram SVG needs none.

When both gems are installed, StreamWeaver also discovers SlimGraphR's optional
**Diagram Intent with SlimGraphR** University course. Its three shipped demos
start with standalone HTML/SVG, compare type/style/theme choices, then use the
same diagram in a live canvas, Canvas Reader and HTML export. The course resolves
each canned artifact from the installed gem, so it never needs this checkout.

## The honest edges

Venn diagrams require exactly two or three sets and complete named pair/triple topology, with one optional authored focal overlap. The fixed equal circles make no area or population claim.

This is an early renderer with explicit boundaries: general graphs allow up to 32 nodes, 64 connections and three groups; timelines allow 32 events. Quadrants allow 2–12 authored points, one optional focal point, and coordinates in [-1,1] outside the central safety band. Sequences allow five participants and twelve messages, with one alternative frame or two optional/repeating frames. State machines allow two to twelve states, at most twice as many transitions as states, and one simple two-to-four-state cycle. Dependency graphs allow 9 nodes, 14 relationships, five ranks, and one marked cycle. Deployment diagrams allow 3 zones, 6 infrastructure nodes, 9 artifact chips, 8 paths, and two combined emphasized nodes/paths. High-level diagrams allow 3–5 phases, 1–4 first-phase sources, 1–2 later-phase components per phase, 8 components, 12 forward data links, one orchestration bar, two crosscuts, and exactly one explicit focal component. Tree diagrams allow depth 1–4, five nodes per tier, five children per parent, and zero or one focal node. Nested containment allows one chain of 3–5 scopes. Layer stacks allow 4–6 bands and exactly one focal layer, with contiguous numeric indices or unique semantic indices. Pyramids allow 4–6 levels, one optional focal level, and measured boundaries with exact continuity and faithful serialization. Medallions allow 3–6 tiers, one focal tier, at most one final archive, adjacent-only promotions, at most two concerns, and at most two write paths. Swimlanes allow 1–6 lanes, 1–12 stages, 24 activities, one activity per cell, and 24 handoffs. Processes add 24 operations, 24 ordinary handoffs plus one optional trigger, and exactly one focal stage and operation. Gantt allows 0–4 phases, 0–12 tasks, up to 8 milestones, 0–2 markers, and one focal task; tasks use exact `[start, finish)` dates. Kanban allows 2–5 columns, 0–4 cards per column, 0–12 cards total, optional positive WIP limits, and one focal card. Journeys allow 2–6 stages, one unique trough, at most two pain markers, and one action per stage. Story maps allow 2–5 activities, 2–3 releases, up to 12 stories total and four per release, one non-final cut, and one risk story. Data-flow diagrams allow 2–4 roles, 2–6 steps, 2–16 transfers, 20 handoffs, and one linked focal claim. Access matrices allow 2–5 roles, 2–10 components, 4–36 explicit permission cells, and zero or one focal cell. At most two nodes/events/states can be emphasized; sequences also allow two headline success messages. Difficult layouts can raise an actionable `LayoutError`; split the diagram or use another tool when it exceeds what the renderer can lay out clearly.

IT current-state diagrams allow 2–4 phases, 1–5 systems per phase, 16 systems, 24 handoffs, two pain points, and three crosscuts. Phase labels are at most 14 uppercase characters and handoff labels at most 8 uppercase characters. High-level phase and vertical concern labels are uppercased and must fit their measured bounds.

Full editorial presentation, broken-axis timelines, and the remaining diagram families are still on the [parity roadmap](docs/roadmap/parity-and-identity.md). The current typography uses conservative width estimates rather than a full text-shaping engine. Each type derives a minimum physical width that keeps body text at least 14px and its smallest meaningful metadata at least 12px. Above that floor the SVG grows with its container; below it, the focusable diagram region scrolls locally instead of turning the diagram into a thumbnail. Standard atlas fixtures fit without diagram scrollbars in a 1360px desktop content column.

All 39 pinned upstream type names now have bounded partial implementations, with 0 missing and 0 fully verified variants. Polar charts encode one ordered series with exact linear rays and no wedges; Radar compares already-common scores with outline-only polygons. Their visible captions state that radial area has no quantitative meaning; see the [polar](docs/polar-charts.md) and [radar](docs/radar-charts.md) guides. Named coverage is complete, but full upstream variant parity is not claimed. No universal token-savings claim follows from one example.

ER diagrams are bounded to 2–6 entities, 1–8 fields per entity, 1–8 relationships, and zero or one focal entity. Database schemas can show one explicit `+ N more columns` row (N 1–99) per table without inventing its hidden columns. Unplaceable models raise `LayoutError` with a split-or-shorten action.

Database-schema diagrams are bounded to 2–5 tables, 1–8 visible columns and 0–3 named indexes per table, and 1–6 explicit foreign keys. Each foreign key attaches to its named source and target column rows and requires declared `FK` and `PK`/`UQ` constraints plus a deletion action. See the [database-schema guide](docs/database-schemas.md).

UML class diagrams use natural-height compartments for literal attributes and operations, plus explicit inheritance, realization, composition, aggregation, association, and dependency relations. Diamonds appear only at an authored owner endpoint, association multiplicities remain at their authored ends with no arrow, and only dependency uses the open arrow. See the [UML class guide](docs/uml-classes.md).

Quadrants preserve literal axis endpoint phrases and exact authored qualitative x/y positions. They never calculate priority or move dots to repair labels; the visible caption states the qualitative limit. See the [quadrant guide](docs/quadrants.md).

Venn diagrams preserve complete named two- or three-set topology in fixed equal circles. Circle and overlap areas never encode quantity, and unplaceable labels fail rather than changing the topology. See the [Venn guide](docs/venn.md).

Loop diagrams require one explicit clockwise `cycle` through five to eight stations and one declared `write_back` from every station to a shared-state hub. The cycle declares its closure; no station order or spoke is inferred. See the [loop guide](docs/loops.md).

Fishbone diagrams require one literal observed effect and two to five categories distributed above and below the spine. Factors are authored investigative leads, and generated descriptions state that they do not prove causation. See the [fishbone guide](docs/fishbones.md).

Wardley maps require explicit qualitative evolution bands, finite authored visibility, and explicit value-chain dependencies. They never infer positions or runtime topology; adjacent rightward movement alone receives the dashed accent arrow. See the [Wardley guide](docs/wardley-maps.md).

## Make the promise executable

```sh
bundle install
bundle exec rspec
ruby bin/check-package
```

The package check builds and installs the gem in isolation, renders the packaged Ruby and JSON examples, and verifies that StreamWeaver is absent. The CI workflow covers the core across Ruby versions and keeps StreamWeaver release/development integration checks in a separate job.

For a core-only development bundle:

```sh
BUNDLE_GEMFILE=gemfiles/core.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/core.gemfile bundle exec rspec --exclude-pattern 'spec/integration/**/*_spec.rb'
```

Contributions that improve the real picture are especially welcome: difficult semantic fixtures, clearer DSL examples, robust routing, accessible output, and carefully implemented new types. Every new type needs its own meaning and evidence, not an alias to a box renderer.

[Usage guide](docs/usage.md) · [Agent authoring guide](docs/for_llms.md) · [Bar guide](docs/bar-charts.md) · [Line guide](docs/line-charts.md) · [Scatter guide](docs/scatter-plots.md) · [Wardley guide](docs/wardley-maps.md) · [Fishbone guide](docs/fishbones.md) · [State-machine guide](docs/state-machines.md) · [Dependency guide](docs/dependencies.md) · [Deployment guide](docs/deployments.md) · [IT current-state guide](docs/it-current-state.md) · [High-level guide](docs/high-level.md) · [Tree guide](docs/trees.md) · [Nested containment guide](docs/nested-containment.md) · [Layer-stack guide](docs/layer-stacks.md) · [Pyramid guide](docs/pyramids.md) · [Medallion guide](docs/medallions.md) · [Swimlane guide](docs/swimlanes.md) · [Process guide](docs/processes.md) · [Gantt guide](docs/gantt.md) · [Kanban guide](docs/kanban.md) · [Journey guide](docs/journeys.md) · [Story-map guide](docs/story-maps.md) · [Benchmark method](docs/benchmark.md)

## Credit where it's due

Cathryn Lavery's **Diagram Design** supplied the editorial inspiration, design-token lineage, and reference grammars. SlimGraphR turns that ambition into a Ruby library that computes the output from intent. Adapted materials retain their [upstream MIT notice](vendor/diagram-design/LICENSE), and the [pinned reference](vendor/diagram-design/README.md) makes the lineage inspectable.

MIT licensed. Built for the joy of saying what you mean.
