# SlimGraphR

[![CI](https://github.com/fkchang/slim_graph_r/actions/workflows/ci.yml/badge.svg)](https://github.com/fkchang/slim_graph_r/actions/workflows/ci.yml)
[![Ruby 3.1+](https://img.shields.io/badge/ruby-3.1%2B-CC342D.svg)](https://www.ruby-lang.org/)
[![MIT](https://img.shields.io/badge/license-MIT-2d3142.svg)](LICENSE)

![A small Ruby drafting press turns a compact description into a clear picture](assets/concepts/ruby-press-v1.jpg)

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

## Install

```sh
gem install slim_graph_r
ruby -r slim_graph_r -e 'File.write("picture.svg", SlimGraphR.diagram(:flowchart) { step :draft; step :publish; flow :draft, :publish }.to_svg)'
```

Or add it to an application:

```sh
bundle add slim_graph_r
```

Open `picture.svg` in your browser. The core renderer needs Ruby 3.1+ and only the extracted standard-library `bigdecimal` and `ostruct` gems. No layout service, API key, browser engine, or StreamWeaver installation is needed to render.

## Give your agent diagram judgment

SlimGraphR ships a progressive-disclosure skill that chooses from the reader's question before it reaches for syntax. The entrypoint routes to one of six families—systems, data, flow, hierarchy, strategy, or quantitative—then loads only that family's type distinctions, evidence gates, and executable Ruby pattern.

```sh
slimgraph install-skill           # this project
slimgraph install-skill --global  # your user skill directories
```

The installer serves Codex, Gemini CLI, GitHub Copilot, and Claude through their standard skill directories. It protects an existing customized skill unless you explicitly pass `--force`.

The chooser is informed by **[Cathryn Lavery's Diagram Design](https://github.com/cathrynlavery/diagram-design)**, [From Data to Viz](https://www.data-to-viz.com/), and the [C4 model](https://c4model.com/diagrams); SlimGraphR's executable examples and limits remain the final contract.

## Pick the question, not the canvas

```ruby
step :draft
decision :review, 'Ready to publish?', emphasis: true
step :publish
step :revise

flow :draft, :review
edge :review, :publish, 'Approved'
edge :review, :revise, 'Needs changes'
```

`flow` handles a chain. `edge` says something specific. IDs become readable names, so `node :background_worker` already knows what belongs in the box. Typos in references fail loudly.

The same small vocabulary drives very different pictures:

<table>
<tr>
<td width="50%"><img src="examples/rendered/readme-deployment.svg" alt="Deployment diagram showing zones, deployed artifacts and network paths"><br><a href="examples/standalone/deployment.rb"><strong>Systems · Deployment</strong></a><br>Where does the software run?</td>
<td width="50%"><img src="examples/rendered/readme-er.svg" alt="Entity relationship diagram showing customer and order cardinality"><br><a href="examples/standalone/entity_relationships.rb"><strong>Data · Entity relationship</strong></a><br>What records relate, and how?</td>
</tr>
<tr>
<td width="50%"><img src="examples/rendered/readme-flowchart.svg" alt="Flowchart with an explicit publishing decision and merge"><br><a href="examples/standalone/flowchart.rb"><strong>Flow · Flowchart</strong></a><br>What decision changes the path?</td>
<td width="50%"><img src="examples/rendered/readme-tree.svg" alt="Tree diagram showing service ownership"><br><a href="examples/standalone/tree.rb"><strong>Hierarchy · Tree</strong></a><br>What decomposes into what?</td>
</tr>
<tr>
<td width="50%"><img src="examples/rendered/readme-quadrant.svg" alt="Quadrant diagram showing authored platform priorities"><br><a href="examples/standalone/quadrant.rb"><strong>Strategy · Quadrant</strong></a><br>Where is the authored tradeoff?</td>
<td width="50%"><img src="examples/rendered/readme-bar.svg" alt="Bar chart comparing signed net bookings"><br><a href="examples/standalone/bar.rb"><strong>Quantitative · Bar</strong></a><br>How much, on one honest scale?</td>
</tr>
</table>

## Thirty-nine grammars, six questions

- **Systems:** architecture, dependency, deployment, high-level, data flow, platform integration
- **Data:** schema, ER, UML class, security matrix, medallion, IT current-state
- **Flow:** flowchart, process, swimlane, state, sequence, journey, story map, Gantt, Kanban, timeline
- **Hierarchy:** org chart, tree, nested containment, layers, pyramid/funnel
- **Strategy:** quadrant, Venn, loop, fishbone, Wardley
- **Quantitative:** bar, line, scatter, treemap, Sankey, polar, radar

Run `slimgraph types` for the machine-readable list, `streamweaver diagrams` for the executable visual atlas, or install the chooser skill described above.

<details>
<summary><strong>All 39 supported type names</strong></summary>

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

</details>

All **39 upstream type names** have bounded partial implementations. At 0.30.0, 39 are partial, 0 remain missing, and 0 are fully verified. Named coverage is complete; full grammar and variant parity are tracked separately in the [coverage matrix](docs/roadmap/parity-matrix.md).

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

## Honest by construction

SlimGraphR refuses to turn a plausible picture into a false claim. Qualitative positions remain authored judgments. Quantitative marks require compatible units and explicit domains. Missing permissions, relationships, dates, capacity and causality are never inferred.

Each type has a bounded grammar and layout budget. Ordinary text remains at least 14px and meaningful metadata at least 12px; narrow containers scroll the diagram locally rather than turning it into a thumbnail. When routing or labels cannot remain faithful, the renderer raises an actionable `LayoutError` and asks you to split or shorten the figure.

The project currently claims **named coverage, not complete upstream parity**: 39 partial, 0 missing, 0 fully verified. See the [coverage matrix](docs/roadmap/parity-matrix.md), [identity and parity policy](docs/roadmap/parity-and-identity.md), and the type guides under [`docs/`](docs/).

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
BUNDLE_GEMFILE=gemfiles/core.gemfile bundle exec rspec --exclude-pattern 'spec/{integration,local}/**/*_spec.rb'
```

Contributions that improve the real picture are especially welcome: difficult semantic fixtures, clearer DSL examples, robust routing, accessible output, and carefully implemented new types. Every new type needs its own meaning and evidence, not an alias to a box renderer.

[Usage guide](docs/usage.md) · [Agent authoring guide](docs/for_llms.md) · [Motion design proposal](docs/motion-contract.md) · [Bar guide](docs/bar-charts.md) · [Line guide](docs/line-charts.md) · [Scatter guide](docs/scatter-plots.md) · [Wardley guide](docs/wardley-maps.md) · [Fishbone guide](docs/fishbones.md) · [State-machine guide](docs/state-machines.md) · [Dependency guide](docs/dependencies.md) · [Deployment guide](docs/deployments.md) · [IT current-state guide](docs/it-current-state.md) · [High-level guide](docs/high-level.md) · [Tree guide](docs/trees.md) · [Nested containment guide](docs/nested-containment.md) · [Layer-stack guide](docs/layer-stacks.md) · [Pyramid guide](docs/pyramids.md) · [Medallion guide](docs/medallions.md) · [Swimlane guide](docs/swimlanes.md) · [Process guide](docs/processes.md) · [Gantt guide](docs/gantt.md) · [Kanban guide](docs/kanban.md) · [Journey guide](docs/journeys.md) · [Story-map guide](docs/story-maps.md) · [Benchmark method](docs/benchmark.md)

## Credit where it's due

Cathryn Lavery's **Diagram Design** supplied the editorial inspiration, design-token lineage, and reference grammars. SlimGraphR turns that ambition into a Ruby library that computes the output from intent. Adapted materials retain their [upstream MIT notice](vendor/diagram-design/LICENSE), and the [pinned reference](vendor/diagram-design/README.md) makes the lineage inspectable.

MIT licensed. Built for the joy of saying what you mean.
