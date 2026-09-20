# Data-flow diagrams

A data-flow diagram answers one bounded question: which role transforms or
hands off which declared payload at each ordered stage? Use `:data_flow` for a
role × stage pipeline. A transfer occupies one role/stage cell; an empty cell
means that role has no declared work there. Payloads belong to transfers, so a
handoff never supplies or infers a conversion.

## Standalone Ruby

The future 0.17 DSL uses `role`, `step`, `transfer`, and `handoff`. Roles need
unique one-to-three-character uppercase keys. Transfers require `tool:` and
may declare a literal `detail:` plus `input:` and `output:` from `:web`,
`:dataset`, `:table`, `:file`, or `:stream`. Details are never inferred from
adjacent cells or payload names.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :data_flow,
  title: 'Declared reporting · pipeline', style: :editorial, theme: :light do
  role :admins, 'Admins', key: 'ADM'
  role :engineers, 'Engineers', key: 'ENG'
  role :scientists, 'Scientists', key: 'SCI'
  role :consumers, 'Consumers', key: 'CON'

  step :collect, 'Collect'
  step :store, 'Store'
  step :prepare, 'Prepare'
  step :analyse, 'Analyse', focal: true
  step :publish, 'Publish'

  transfer :setup, 'Setup', role: :admins, step: :collect, tool: 'Console'
  transfer :ingest, 'Ingest', role: :engineers, step: :collect,
           tool: 'SFTP', output: :dataset
  transfer :stage, 'Stage', role: :engineers, step: :prepare,
           tool: 'Trino', detail: 'raw → trusted table', input: :dataset, output: :table
  transfer :model, 'Model', role: :scientists, step: :analyse,
           tool: 'Notebook', input: :table, output: :file, focal: true
  transfer :query, 'Query', role: :consumers, step: :publish,
           tool: 'Read-only SQL', input: :table

  handoff :setup, :ingest, kind: :trigger
  handoff :stage, :model, kind: :focal, label: 'ANON DATA'
  handoff :model, :query, kind: :publish
end

File.write('data-flow.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

The focal step, focal transfer, and focal handoff are one linked focal triple:
the handoff must target the focal transfer in the focal step. A trigger is an
unlabelled same-step downward role handoff. Ordinary and publish handoffs move
to a later step. Only the focal handoff accepts its required uppercase label.

## Equivalent strict JSON

JSON mirrors `roles`, `steps`, `transfers`, and `handoffs`; it does not use a
generic `nodes`/`edges` graph. This is the same model as the Ruby example,
including its literal Unicode title.

```json
{
  "type": "data_flow",
  "title": "Declared reporting · pipeline",
  "style": "editorial",
  "theme": "light",
  "roles": [
    {"id": "admins", "label": "Admins", "key": "ADM"},
    {"id": "engineers", "label": "Engineers", "key": "ENG"},
    {"id": "scientists", "label": "Scientists", "key": "SCI"},
    {"id": "consumers", "label": "Consumers", "key": "CON"}
  ],
  "steps": [
    {"id": "collect", "label": "Collect"},
    {"id": "store", "label": "Store"},
    {"id": "prepare", "label": "Prepare"},
    {"id": "analyse", "label": "Analyse", "focal": true},
    {"id": "publish", "label": "Publish"}
  ],
  "transfers": [
    {"id": "setup", "label": "Setup", "role": "admins", "step": "collect", "tool": "Console"},
    {"id": "ingest", "label": "Ingest", "role": "engineers", "step": "collect", "tool": "SFTP", "output": "dataset"},
    {"id": "stage", "label": "Stage", "role": "engineers", "step": "prepare", "tool": "Trino", "detail": "raw → trusted table", "input": "dataset", "output": "table"},
    {"id": "model", "label": "Model", "role": "scientists", "step": "analyse", "tool": "Notebook", "input": "table", "output": "file", "focal": true},
    {"id": "query", "label": "Query", "role": "consumers", "step": "publish", "tool": "Read-only SQL", "input": "table"}
  ],
  "handoffs": [
    {"from": "setup", "to": "ingest", "kind": "trigger"},
    {"from": "stage", "to": "model", "kind": "focal", "label": "ANON DATA"},
    {"from": "model", "to": "query", "kind": "publish"}
  ]
}
```

Parse the same model directly from a file:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('data-flow.json'))
File.write('data-flow.svg', diagram.to_svg)
diagram
```

The strict parser never evaluates JSON as Ruby. Unknown, cross-type, `null`,
wrongly typed, duplicate, malformed, over-budget, or unresolved fields raise
`SlimGraphR::Error`. Optional `input` and `output` are omitted when unknown;
they are never `null`. No payload conversion, lineage, or route is inferred
from adjacent cells, matching payload names, or a handoff.

Without `description:`, SVG receives the generated accessible description
described below. Supplying `description:` replaces it exactly; the generated
sentences are omitted.

## CLI and optional StreamWeaver

With the 0.17 source/API available, use the repository executable or an
installed `slimgraph` command:

```sh
ruby -Ilib exe/slimgraph render data-flow.rb -o data-flow.svg
ruby -Ilib exe/slimgraph render data-flow.json -o data-flow.html --format html
slimgraph render data-flow.json -o data-flow-installed.svg
```

JSON is the file default. For Ruby on standard input, pass
`--input-format ruby`; the Ruby document must leave `diagram` as its final
expression. `--style` and `--theme` change presentation only.

The optional adapter is loaded separately and uses the same block:

```ruby
require 'slim_graph_r/stream_weaver'

# Build the same SlimGraphR.diagram(:data_flow, ...) document above.
```

## Layout, semantics, and limits

The layout is a deterministic horizontal grid: a measured role-label column,
168px step slots, a 40px outer right margin, a 36px step header, and 116px
role bands. Transfers without a detail use fixed 152×72px cards; a declared
detail uses a measured 152×100px card with title, detail, tool, and payload
badges in separate rows. Keep role, step, transfer, detail, tool, and handoff
labels short enough for their measured lanes; text that cannot fit raises
`SlimGraphR::LayoutError` rather than wrapping outside the card, truncating,
or moving a transfer to another cell.

Role keys and payload badges are measured at their rendered 12px mono weight,
use 16px-high chips with horizontal padding, and share the same width budgets
with the legend. Adjacent titles begin after the measured role chip rather than
after a fixed badge slot.

Ordinary and publish routes advance orthogonally. Triggers use a direct
vertical path. The focal route uses one rightward corridor and a vertical
arrival; its uppercase label has a paper mask and visible gap. Routes have
distinct ports, at least 12px parallel separation, no diagonal strokes, no
shared stroke segment, and no traversal through unrelated cards. Crossings,
blocked routes, overfull legends, or unplaceable text raise
`SlimGraphR::LayoutError`.

The bounded model requires 2–4 roles, 2–6 steps, at least two transfers, at
most 16 transfers, and at most 20 handoffs. It requires exactly one focal
step, one focal transfer, and one focal handoff. It rejects arbitrary colors,
icons, coordinates, generic graph fields, extra edge labels, more than one
focal claim, and other topology outside the declared handoff kinds.

The generated accessible description names role and step order, each declared
transfer, tool, payload, handoff kind, and focal claim. This is bounded partial
parity with the pinned [Cathryn Lavery Diagram Design data-flow
reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-data-flow.md).
SlimGraphR is independent; upstream MIT attribution remains in
`vendor/diagram-design`. The core renderer has no runtime dependency on
StreamWeaver, and the adapter remains optional.
