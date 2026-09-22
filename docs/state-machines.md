# State machines

SlimGraphR’s state-machine type describes a bounded lifecycle: named states, one entry state, one or two terminal states, and named transitions between them. It is a dedicated model, so state-machine meaning stays separate from generic graph nodes and edges.

## Ruby

Require the core gem and call `SlimGraphR.diagram(:state)`. A state ID is a stable reference; its optional label is what readers see. Without a label, the ID is turned into a readable name. Mark the entry with `initial` and terminal states with `final`. Every transition needs an event in `on:`; `guard:` and `action:` are optional.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :state,
  title: 'Publish lifecycle', direction: :right, style: :editorial, theme: :light do
  state :draft, 'Draft'
  state :review, 'In review'
  state :published, 'Published', emphasis: true

  initial :draft
  final :published

  transition :draft, :review,
    on: 'submit', guard: 'complete?', action: 'queue'
  transition :review, :draft, on: 'request changes'
  transition :review, :review, on: 'recheck', action: 'record audit'
  transition :review, :published, on: 'approve'
end

File.write('state-machine.svg', diagram.to_svg)
diagram # The final expression lets `slimgraph render` use this Ruby file as input.
```

When Ruby source is passed to `slimgraph render`, its final expression must return the diagram. Keep `diagram` after any side effect such as `File.write`. Transition text is composed as `event [guard] / action`; absent guard or action parts are omitted. A self-loop records repetition. An incoming transition to the initial state records recovery and does not change which state is the entry marker. A final state cannot have outgoing transitions.

`direction` defaults to `:right`; `:down` is also supported. `style` (`:editorial`, `:ruby`, `:blueprint`, or `:mono`) and `theme` (`:light`, `:dark`, or `:auto`) change presentation while preserving the model and geometry. `diagram.to_svg` returns a standalone SVG; `diagram.to_html` wraps it in a minimal HTML page. The SVG title and description retain states, entry/final markers, events, guards, actions, self-loops, and feedback transitions.

## JSON

JSON is data and is parsed strictly; it is never evaluated as Ruby. The state fields replace `nodes`, `edges`, `groups`, and `events`:

```json
{
  "type": "state",
  "title": "Publish lifecycle",
  "direction": "right",
  "style": "editorial",
  "theme": "light",
  "states": [
    {"id": "draft", "label": "Draft"},
    {"id": "review", "label": "In review"},
    {"id": "published", "label": "Published", "emphasis": true}
  ],
  "initial": "draft",
  "finals": ["published"],
  "transitions": [
    {"from": "draft", "to": "review", "on": "submit", "guard": "complete?", "action": "queue"},
    {"from": "review", "to": "draft", "on": "request changes"},
    {"from": "review", "to": "review", "on": "recheck", "action": "record audit"},
    {"from": "review", "to": "published", "on": "approve"}
  ]
}
```

The JSON model has exactly these state-specific fields: `states`, required `initial`, required `finals`, and `transitions`. Each state accepts `id`, optional `label`, and optional boolean `emphasis`. Each transition accepts `from`, `to`, `on`, and optional `guard` and `action`. Shared document options include `title`, `description`, `direction`, `style`, and `theme`. Unknown keys, null values, blank identifiers or text, cross-type arrays (`nodes`, `edges`, `groups`, `events`, `steps`, `escalations`, or `approvals`), and incorrectly typed values raise `SlimGraphR::Error`.

Ruby and JSON use the same immutable state and transition records and the same renderer. To render JSON through the library:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('state-machine.json'))
File.write('state-machine.svg', diagram.to_svg)
```

## StreamWeaver and the CLI

For a StreamWeaver document, require `slim_graph_r/stream_weaver` and use the shared `diagram` block:

```ruby
require 'slim_graph_r/stream_weaver'

diagram :state, title: 'Publish lifecycle' do
  state(:draft, 'Draft')
  state(:published, 'Published')
  initial :draft
  final :published
  transition :draft, :published, on: 'approve'
end
```

Use parentheses in `state(...)` in StreamWeaver source. The bridge currently has a lexical `state` binding, so the parenthesized call selects the DSL method reliably. The core Ruby DSL remains `state :id, 'Label'`.

The CLI renders either form:

```sh
slimgraph render state-machine.rb -o state-machine.svg
slimgraph render state-machine.json -o state-machine.svg
slimgraph render state-machine.json --style blueprint --theme dark -o state-machine.html
```

The input extension selects Ruby or JSON. Use `--input-format ruby` for Ruby source from stdin; JSON is the stdin default. `--format svg|html` selects output explicitly, and existing files require `--force`. The packaged executable examples are `examples/standalone/state_machine.rb`, `examples/standalone/state_machine.json`, and `examples/stream_weaver/state_machines.rb`.

For local development, build and install the exact checkout artifact without a global dependency:

```sh
gem build slim_graph_r.gemspec
gem install --local --no-document ./slim_graph_r-0.7.0.gem
slimgraph render examples/standalone/state_machine.json -o state-machine.svg
```

The core renderer depends only on the extracted standard-library `bigdecimal` and `ostruct` gems. StreamWeaver is an optional adapter and is not required for the standalone gem or CLI.

## Validation and limits

`state id, label, detail:` accepts an optional literal per-state detail. It is neither a generated status nor a transition annotation. Details are measured as up to three monospaced lines inside their own state card; text that cannot fit raises `SlimGraphR::LayoutError` with advice to shorten it or split the diagram.

State machines must contain two to twelve states, at least one transition, and at most twice as many transitions as states. IDs are distinct and nonblank. There is exactly one initial state and one or two distinct final states; all marker and transition references must name declared states. Every state must be reachable from the initial state and able to reach a final state. Each final state has no outgoing transitions. A state may have at most four incoming and four outgoing transitions, with one transition per ordered pair and at most one self-loop per state. At most two states may be emphasized.

The bounded topology allows one simple directed multi-state cycle containing two to four states. Nested or overlapping cycles, composite/history states, forks, anonymous transitions, and “from any state” arrows are outside this slice. Text and input-size limits shared by the document apply as well.

Layout uses rounded state boxes, a filled entry dot, ringed final dots, curved transition paths, an outside feedback lane for a multi-state cycle, and loops above their state. Labels use measured monospaced boxes. The numeric budgets are necessary but do not guarantee a clear scene: a dense graph or long label may leave no clear route or label position. In that case rendering raises `SlimGraphR::LayoutError` with a request to shorten labels, try the other direction, or split the state machine. A successful SVG string alone does not establish that a browser page is readable, so inspect real rendered examples at the intended width. The renderer may reject a layout rather than draw crossing curves or place a label over another curve.

This is bounded partial parity with the pinned upstream [Cathryn Lavery Diagram Design state reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-state.md). SlimGraphR is an independent Ruby implementation; the upstream MIT notice and reference lineage remain in `vendor/diagram-design`.
