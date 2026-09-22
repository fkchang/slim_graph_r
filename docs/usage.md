# SlimGraphR

Editorial SVG diagrams from a small Ruby vocabulary. Ruby handles layout, wrapped labels, and rounded orthogonal connectors. The renderer needs no browser layout engine and depends only on the extracted standard-library `bigdecimal` and `ostruct` gems.

```ruby
require 'slim_graph_r'

review = SlimGraphR.diagram :flowchart, title: 'From draft to published' do
  step :draft
  decision :review, 'Ready to publish?', emphasis: true
  step :publish
  step :revise

  flow :draft, :review
  edge :review, :publish, 'Approved'
  edge :review, :revise, 'Needs changes'
end

File.write('review.svg', review.to_svg)
File.write('review.html', review.to_html)
```

Inspired by [Cathryn Lavery’s Diagram Design](https://github.com/cathrynlavery/diagram-design). SlimGraphR brings that editorial ambition to an independent Ruby renderer with compact authoring. Full parity is our goal; see the [39-type coverage matrix](roadmap/parity-matrix.md) for current gaps and evidence.

## StreamWeaver

Install the gem locally with `gem build slim_graph_r.gemspec` followed by `gem install ./slim_graph_r-0.5.1.gem --no-document`, or add a Bundler path dependency while developing:

```ruby
gem 'slim_graph_r', path: '../slim_graph_r'
```

Load the extension in your app or saved canvas document:

```ruby
require 'slim_graph_r/stream_weaver'

diagram :architecture, title: 'Request handling' do
  external :client
  node :api, 'API', emphasis: true
  store :database
  flow :client, :api, :database
end
```

The extension adds `diagram` to StreamWeaver's shared DisplayDSL and supplies a component that renders through its existing Phlex interface. It needs no changes to StreamWeaver itself. The gem must be available to the process rendering the document. When developing, remember that a long-running canvas bridge retains Ruby code it has already loaded.

Verified with StreamWeaver 0.3.x: app component rendering, live bridge push/get_dsl, saved-document reader, HTML export, and the packaged Chrome viewer's browser-side Opal runtime. The Chrome viewer bundles the narrow `slim_graph_r/stream_weaver_opal` entrypoint and renders Ruby or Org saved documents as inline SVG without a Ruby server or network asset. The complete 39-type atlas is the compatibility fixture; each SVG retains its accessible title and description.

## A small vocabulary

| Diagram | Content | Connections |
| --- | --- | --- |
| `:architecture` | `node`, `store`, `external`, `group` | `edge`, `flow` |
| `:flowchart` | `step`, `decision`, `group` | `edge`, `flow` |
| `:org_chart` | `node` | `edge`, `flow` |
| `:sequence` | `participant` | `message` in chronological order |
| `:timeline` | `event` on a date axis or ordered milestone list | `scale: :date`, `:ordered`, or `:auto` |
| `:wardley` | `component` with qualitative evolution and authored visibility | `depends_on`; optional adjacent `evolving_to` |

IDs become readable labels: `node :background_worker` displays “Background worker.” Pass a label for acronyms or precise wording. References must name declared nodes; typos are errors rather than silently created nodes. `flow :a, :b, :c` connects consecutive nodes. `edge :a, :b, 'Next'` and `edge :a, :b, label: 'Next'` are equivalent.

```ruby
SlimGraphR.diagram :sequence, title: 'Cache lookup' do
  participant :client
  participant :service, emphasis: true
  message :client, :service, 'Fetch document'
  message :service, :service, 'Check cache'
  message :service, :client, 'Cached result', dashed: true
end

SlimGraphR.diagram :timeline, title: 'Delivery', scale: :date do
  event '2026-01-08', 'Define the model'
  event '2026-02-04', 'Ship the renderer', emphasis: true
  event '2026-03-21', 'Publish the guide', detail: 'Examples are executable.'
end
```

`group(:backend, 'Backend') { node :api; store :database }` adds a non-nested boundary in architecture/flowchart diagrams. Groups occupy separate layout lanes.

## Appearance and accessibility

Use `theme: :light`, `:dark`, or `:auto`. Auto follows OS dark mode and StreamWeaver's light/dark page selectors. Graph diagrams accept `direction: :right` or `:down`; architecture defaults right, flowcharts and org charts down. Sequence and timeline use their own fixed layouts.

Each SVG includes a title, a textual description of its content and connections, and unique IDs. Pass `description:` for a custom screen-reader summary. The SVG fills and can grow with its container while retaining a content-derived minimum width for 14px body and 12px metadata text. Below that floor, the StreamWeaver wrapper scrolls horizontally; static SVG/HTML uses the same minimum.

The font stacks prefer Instrument Serif, Geist, and Geist Mono, with Georgia, Helvetica/Arial, and system monospace fallbacks. Fonts are not downloaded or bundled. The checked gallery uses fallbacks. The light accent is darkened from the reference for text contrast.

## Supported boundaries

Treemaps accept 2–12 nonnegative items with at least one positive value and one optional focal border; exact positive area is preserved, zero has no cell, and tiny copy moves to the external legend. Sankeys accept exactly three stages, 3–10 positive nodes, and 2–16 positive adjacent-stage flows with exact node and stage conservation. One scale drives all node heights and ribbon thicknesses; a subpixel ribbon fails. See [treemaps.md](treemaps.md) and [sankeys.md](sankeys.md).

This release supports up to 32 nodes/events, 64 edges/messages, and three groups, with at most two emphasized elements. Wardley maps have a dedicated 2–9 component, 1–12 dependency, two-movement budget and require every component to be incident. Graph layout handles branches, merges, cycles, self-loops, repeated edges, and disconnected nodes. Org charts allow one parent per node and reject cycles. Sequences support self-messages, calls/returns/notifications, scoped activation bars and alt/opt/loop frames, with stricter five-participant/twelve-message limits. See [sequence conversations](sequence.md) and [Wardley maps](wardley-maps.md).

This is a bounded layout engine, not a full implementation of diagram-design's 39 diagram types. Dense graphs or long edge annotations may have no clear route/label placement and raise `SlimGraphR::LayoutError`; simplify or split the diagram, or use StreamWeaver's existing `mermaid` method. Routing avoids node interiors and reserves separate parallel paths. Ordinary crossings use an eight-pixel hop on the later/secondary path. Layouts that cannot leave room for distinct paths or hops raise LayoutError. Optimal crossing minimization, nested groups, broken-axis timelines, Mermaid import, animation, and PNG export are not included. Complete calendar dates use a linear elapsed-day axis; see [timeline.md](timeline.md).

Label sizing uses conservative Unicode-aware estimates, not a font shaping engine. Complex script shaping and unusually wide custom fonts may need visual review. Layout is deterministic; generated SVG IDs are unique by default. `to_svg(id: 'example')` makes output reproducible, but the caller must keep explicit IDs unique within a page.

## Development

```sh
bundle install
bundle exec rspec
```

The development bundle includes StreamWeaver for integration specs; the core gem depends only on the extracted standard-library `bigdecimal` and `ostruct` gems. See [StreamWeaver gallery](../examples/stream_weaver/gallery.rb), [Agent guide](for_llms.md), and [Benchmark](benchmark.md).

MIT. Design tokens and editorial conventions are adapted from [diagram-design](https://github.com/cathrynlavery/diagram-design), pinned and credited under [vendor/diagram-design](../vendor/diagram-design/README.md).

## CLI and named styles

`slimgraph render INPUT.rb|INPUT.json -o OUTPUT.svg|OUTPUT.html` renders one diagram. `--style ruby` and `--theme dark` override presentation. Existing output files require `--force`; no destination writes SVG to stdout. JSON stdin is supported with `slimgraph render -`. See [JSON input](json-input.md).

Use `style: :editorial` (default), `:ruby`, `:blueprint`, or `:mono` independently from `theme: :light/:dark/:auto`. For existing models, `diagram.with(style: :ruby, theme: :dark)` returns a new frozen model with the same content.

## Flowchart semantics (0.3.0)

`start :request`, `decision :ready, "Ready?"`, `merge :joined`, and `finish :done` render distinct flowchart shapes. A merge is an unlabeled visible dot; its ID-derived name is included in the accessible description. It needs two or three incoming edges and one outgoing edge. Merge points cannot carry detail text or emphasis. Start nodes have no incoming edges; finish nodes have no outgoing edges. Decisions allow at most three exits, all with nonblank labels. For simple ungrouped top-down Yes/No branches, the positive path is placed right and the negative path below. Other guards choose distinct ports toward their targets.

Shared graph routing leaves at least 12px between parallel strokes and 8px between label masks and connector centerlines. Merge dots are explicit junctions, with their small boundary ports as the intentional exception to the usual port spacing. These features are a parity slice, not a full upstream parity certification.

## Sequence control (0.4.0)

Use `activate`, `alt`/`branch`, `opt` and guarded `loop` blocks to preserve control meaning. Every block executes once while constructing the model. `reply` is a dashed filled return; `notify` is a dashed open asynchronous message. Existing `dashed: true` sequences map to returns. Full syntax and limits are in [sequence.md](sequence.md).
