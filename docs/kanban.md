# Kanban diagrams (0.15 draft)

This is the proposed 0.15 tutorial for `:kanban`, a static work-state census.
The author supplies columns, cards, optional metadata, optional states, and an
optional WIP policy. SlimGraphR does not fetch, create, reorder, filter, or
infer ticket records.

## Standalone Ruby

Declare columns and cards in the order they should appear. A column's count is
derived from the cards displayed in it. Card state is supplied data and may
intentionally differ from the containing column's label.

Under the shared document contract, `title` defaults to `Diagram`, `style` to
`:editorial`, and `theme` to `:light`; `description` is optional. Styles are
`:editorial`, `:ruby`, `:blueprint`, or `:mono`, and themes are `:light`,
`:dark`, or `:auto`.

Ruby may omit a record's label to use the humanized ID; the JSON branch below
uses explicit labels because strict JSON requires `label` on columns and cards.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :kanban,
  title: 'Platform work · 平台工作', style: :editorial, theme: :light do
  column :backlog, 'Backlog · 待办' do
    card :api, 'API contract · 接口契约'
  end

  column :build, 'In progress · 进行中', wip_limit: 1 do
    card :cache, 'Cache migration · 缓存迁移', state: :blocked, focal: true
    card :docs, 'Release notes · 发布说明', ticket: 'AVA-216', state: :waiting
  end

  column :done, 'Done · 完成' do
    card :lint, 'Lint cleanup · 清理检查', owner: 'nadia', state: :done
  end
end

File.write('work.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

`column` accepts an optional positive integer `wip_limit:`. Omission means
there is no known WIP policy, so the header displays a bare count. The column
name or position never supplies a queue, in-progress, or terminal state.

`card` accepts optional nonblank `ticket:` and `owner:` strings, and optional
`state:` of `:default`, `:blocked`, `:waiting`, or `:done`. Omitted state is
neutral `:default`. `focal:` is a strict boolean, defaults to `false`, and at
most one card may be focal. A focal card receives a distinct 2px ink ring;
state treatments remain visible beneath it.

## Equivalent strict JSON

The following JSON is field-for-field equivalent to the Ruby example above.
Order in both arrays is meaningful and must be preserved.

```json
{
  "type": "kanban",
  "title": "Platform work · 平台工作",
  "style": "editorial",
  "theme": "light",
  "columns": [
    {
      "id": "backlog",
      "label": "Backlog · 待办",
      "cards": [
        {"id":"api", "label":"API contract · 接口契约"}
      ]
    },
    {
      "id": "build",
      "label": "In progress · 进行中",
      "wip_limit": 1,
      "cards": [
        {"id":"cache", "label":"Cache migration · 缓存迁移", "state":"blocked", "focal":true},
        {"id":"docs", "label":"Release notes · 发布说明", "ticket":"AVA-216", "state":"waiting"}
      ]
    },
    {
      "id": "done",
      "label": "Done · 完成",
      "cards": [
        {"id":"lint", "label":"Lint cleanup · 清理检查", "owner":"nadia", "state":"done"}
      ]
    }
  ]
}
```

The JSON root allowlist is `{type,title,description,style,theme,columns}`.
A column accepts `{id,label,wip_limit,cards}`; a card accepts
`{id,label,ticket,owner,state,focal}`. Optional fields are omitted when
unknown; explicit `null` is not an alternative to omission. Unknown keys,
missing required keys, wrong JSON types, duplicate IDs, blank IDs/labels,
blank metadata, and cross-type fields raise `SlimGraphR::Error`.

The strict JSON `columns` array is required, and every column's `cards` array
is required, including when it is empty. A board still needs two to five
columns.

Load the same strict document through the library parser:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('work.json'))
File.write('work.svg', diagram.to_svg)
diagram
```

JSON is parsed and validated; it is never evaluated as Ruby.

## CLI and optional StreamWeaver

The direct CLI forms are:

```sh
ruby -Ilib exe/slimgraph render work.rb -o work.svg
ruby -Ilib exe/slimgraph render work.json -o work.html --format html
```

The file extension selects Ruby or JSON. JSON is the stdin default; use
`--input-format ruby` for Ruby source from stdin. `--style` and `--theme`
override presentation without changing the model. Output defaults to SVG;
`--format html` selects the small HTML wrapper. A Ruby input must leave
`diagram` as its final expression, after any `File.write` call.

The planned parity examples cover all four styles (`editorial`, `ruby`,
`blueprint`, and `mono`) and both `light` and `dark` themes.

Board direction is fixed; `direction:` is not a Kanban option.

The core renderer depends only on the extracted standard-library `bigdecimal` and `ostruct` gems. StreamWeaver is optional and
is loaded explicitly with `require 'slim_graph_r/stream_weaver'`; it is not
required for standalone Ruby or JSON use.

## State, counts, and geometry

Render 2–5 declaration-ordered columns, each 240px wide with 32px gutters.
Headers use an honest derived count. With a supplied positive limit, the
header displays the actual `n/limit`; when `n > limit`, accent text and stroke
identify the violation. Without a limit, the header displays bare `n`.
WIP breaches are accepted and remain visible; the renderer never silently
repairs a limit.

`blocked`, `waiting`, and `done` always receive their specified treatments.
Every blocked card gets its accent bar and dashed outline, including when
several blocked cards exist. These severity treatments and WIP violation
chips are exceptions to the generic focal-color budget. A focal card's 2px
ink ring coexists with its state color. Draw no connectors.

Cards are 56px high with a 12px gap and a 16px column inset. Titles wrap.
The monospace sublabel appears only for supplied metadata: `TICKET · owner`,
ticket alone, or owner alone. A column may be empty; that is meaningful input.
Column and card declaration order is retained exactly. No state is inferred
from names or positions, and cards are never sorted or aggregated.

If measured card-title or metadata geometry cannot fit, the planned renderer
raises an actionable `SlimGraphR::LayoutError`. It does not substitute `+N
more`, drop cards, change counts, reorder records, or reject a WIP breach
because the column is over limit. Geometry, rather than semantic status
density, determines layout failure.

More than four cards in one column or more than twelve cards on the board also
raises `SlimGraphR::LayoutError`; split the board without aggregation or
dropping cards.

## Limits and deferred semantics

The bounded slice permits 2–5 columns, 0–4 cards per column, and 0–12 cards
total. A board must therefore have at least two columns, while an empty column
is valid. IDs are nonblank strings and globally unique within the declared
family; labels, tickets, and owners are nonblank UTF-8 strings after normal
`Text.clean` handling. There may be zero or one focal card. WIP limits are
either omitted or positive integers. States are exactly `default`, `blocked`,
`waiting`, or `done`; omitted state becomes `default`. Shared input limits
also apply: text fields are at most 300 characters and a JSON input is at
most 1 MiB.

Swimlanes, arrows or transitions, sorting, filtering, ticket fetching or
creation, avatars, per-person grouping, automatic archival, cumulative-flow
analytics, and dynamic WIP changes are deferred. The board is a supplied
census, not a workflow engine.

When `description` is omitted, generated accessibility text reports column
order, actual counts, known WIP limits and violations, every card's declared
or default state, supplied ticket/owner metadata, and the focal card. An
author-supplied `description` replaces that generated prose. This draft
describes the proposed 0.15 contract; it is not an implementation or a test
report.

The editorial direction is informed by the pinned [Cathryn Lavery Diagram
Design reference](https://github.com/cathrynlavery/diagram-design/tree/dcd9317ed9ec7477b20005544f36e3313664d815).
SlimGraphR remains an independent renderer; attribution and the upstream MIT
notice stay under `vendor/diagram-design`.

For release verification, run the literal Ruby and JSON examples under both
the checkout and installed gem with an explicit C locale, then inspect the
real standalone HTML page at desktop and narrow widths. A successful SVG
string alone does not establish browser-page correctness.
