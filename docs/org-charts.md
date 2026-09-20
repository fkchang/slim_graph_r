# Org charts

An org chart describes accountable people or teams and the reporting relationships between them. SlimGraphR keeps ownership details separate so a reader can tell a name, an invocation route, a responsibility scope, an availability state, and an explicit setup gap apart. Reporting edges are part of the hierarchy; escalation, approval, and setup-gap records appear in a footer strip as operating rules.

## Standalone Ruby

Require the core gem and build an `:org_chart` with `SlimGraphR.diagram`. `owner` takes an ID and a human-facing name. Its second argument uses the same label slot as a generic `node`, so existing `node` calls remain valid. `invoke` and `scope` are optional strings; `detail`, `kind`, and `emphasis` are the shared node options. `unavailable: true` keeps an owner visible while marking the setup gap.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :org_chart,
  title: 'Northstar studio ownership',
  style: :editorial,
  theme: :light do
  owner :lead, 'Northstar lead',
    invoke: '@northstar',
    scope: 'Direction and release approval',
    emphasis: true
  owner :intake, 'Intake team',
    invoke: '#northstar-help',
    scope: 'Routing and escalation'
  owner :archive, 'Archive owner',
    scope: 'Long-term records',
    unavailable: true,
    detail: 'Setup pending'

  edge :lead, :intake
  edge :intake, :archive
  escalation 'Unowned work', to: :intake
  approval 'Production release', by: :lead
end

File.write('org-chart.svg', diagram.to_svg)
```

Use `diagram.to_html` when a self-contained HTML page is more convenient. The complete executable contract, with a second reporting branch and an editorial light theme, is [examples/standalone/org_ownership.rb](../examples/standalone/org_ownership.rb). Render it with:

```sh
slimgraph render examples/standalone/org_ownership.rb -o org-chart.svg
```

`node` can carry the ownership fields when an explicit owner helper is not useful:

```ruby
node :triage, 'Triage',
  invoke: '#help',
  scope: 'Routing, escalation',
  unavailable: false,
  detail: 'Optional existing detail',
  kind: :service
```

The `owner` helper and generic `node` form produce the same model. `escalation 'Label', to: :owner_id`, `approval 'Label', by: :owner_id`, and `setup_gap 'Label', for: :owner_id` require an existing node ID. Setup gaps are literal records; `unavailable: true` continues to mark a card but does not invent a footer callout. Footer records are never reporting nodes.

## Equivalent strict JSON

JSON uses the same labels, node fields, edges, and footer records. The org-only node fields are `invoke` (string), `scope` (string), and `unavailable` (boolean). The top-level `escalations`, `approvals`, and `setup_gaps` arrays contain objects with `label` plus `to`, `by`, or `for`:

```json
{
  "type": "org_chart",
  "title": "Northstar studio ownership",
  "style": "editorial",
  "theme": "light",
  "nodes": [
    {
      "id": "lead",
      "label": "Northstar lead",
      "invoke": "@northstar",
      "scope": "Direction and release approval",
      "emphasis": true
    },
    {
      "id": "intake",
      "label": "Intake team",
      "invoke": "#northstar-help",
      "scope": "Routing and escalation"
    },
    {
      "id": "archive",
      "label": "Archive owner",
      "scope": "Long-term records",
      "unavailable": true,
      "detail": "Setup pending"
    }
  ],
  "edges": [
    { "from": "lead", "to": "intake" },
    { "from": "intake", "to": "archive" }
  ],
  "escalations": [
    { "label": "Unowned work", "to": "intake" }
  ],
  "approvals": [
    { "label": "Production release", "by": "lead" }
  ]
}
```

The full packaged JSON contract is [examples/standalone/org_ownership.json](../examples/standalone/org_ownership.json). Render it with the same CLI:

```sh
slimgraph render examples/standalone/org_ownership.json -o org-chart.svg
```

The parser is strict and never evaluates JSON as Ruby. Unknown keys, blank `invoke` or `scope`, non-boolean `unavailable`, missing node references, and malformed rule records raise errors. Org-only fields and arrays raise on every other diagram type, including an empty `escalations` or `approvals` array. Ruby and JSON use the same validated model and rendering path.

## Limits and layout behavior

The org-specific budgets are:

- 12 visible nodes;
- four tiers, counting a root as tier 1;
- five direct reports for any one parent;
- one emphasized org node; and
- two escalation/approval callouts and three explicit setup-gap callouts.

Each child may have one incoming reporting edge. Cycles fail during construction. Disconnected roots are valid, so a forest can be used when the source material has more than one top-level owner. Shared model limits also apply, including distinct IDs and the 300-character text limit.

Org charts default to `direction: :down`; use `direction: :right` when a wide hierarchy reads better. The renderer routes reporting connectors orthogonally and places footer records after a divider in a reserved strip. The footer strip is blocked geometry, so connectors remain above it. Names and scopes use sans-serif text; invocation strings and unavailable status use the monospace role. Generated SVG descriptions include names, invocation, scope, unavailable state, reporting edges, rules, and setup gaps.

This is bounded, partial parity with the upstream org-chart reference. Connectors are routed independently, so a shared sibling bus is not guaranteed. Existing `kind` palette treatments are reused instead of introducing an org-only role taxonomy. Summary cards and legends are outside this slice. See the [parity boundary](roadmap/parity-and-identity.md) and [parity matrix](roadmap/parity-matrix.md).

For a StreamWeaver document, require `slim_graph_r/stream_weaver` and use the same block DSL. The two-theme gallery is [examples/stream_weaver/org_charts.rb](../examples/stream_weaver/org_charts.rb).
