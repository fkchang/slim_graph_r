# IT current-state diagrams

An IT current-state diagram records the systems and handoffs that exist before
a modernization. It uses horizontal phases; it does not promise deployment
placement or a future architecture.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram(:it_state, title: 'Current IT Landscape',
  subtitle: 'Data pipeline before the platform', eyebrow: 'NatStat · Before') do
  phase :collect, 'COLLECT' do
    system :survey, 'Survey Solutions', detail: 'CAPI · PostgreSQL'
    system :registry, 'Civil Registry', detail: 'CRVS', state: :external
  end
  phase :process, 'PROCESS' do
    system :drive, 'Shared Drive', detail: 'No version control', state: :pain_point
  end
  phase :publish, 'PUBLISH' do
    system :portal, 'Data Portal', detail: 'Public release'
  end
  handoff :survey, :drive, 'CSV', style: :link
  handoff :registry, :drive, 'EXCEL', style: :link, dashed: true
  handoff :drive, :portal, 'PUBLISH', style: :accent
  crosscut :identity, 'Identity Manager', detail: 'AD · LDAP · SSO'
end

File.write('it-state.svg', diagram.to_svg)
diagram
```

The equivalent strict JSON is data, not executable Ruby:

```json
{
  "type": "it_state",
  "title": "Current IT Landscape",
  "subtitle": "Data pipeline before the platform",
  "eyebrow": "NatStat · Before",
  "phases": [
    {"id": "collect", "label": "COLLECT", "systems": [
      {"id": "survey", "label": "Survey Solutions", "detail": "CAPI · PostgreSQL"},
      {"id": "registry", "label": "Civil Registry", "detail": "CRVS", "state": "external"}
    ]},
    {"id": "process", "label": "PROCESS", "systems": [
      {"id": "drive", "label": "Shared Drive", "detail": "No version control", "state": "pain_point"}
    ]},
    {"id": "publish", "label": "PUBLISH", "systems": [
      {"id": "portal", "label": "Data Portal", "detail": "Public release"}
    ]}
  ],
  "handoffs": [
    {"from": "survey", "to": "drive", "label": "CSV", "style": "link"},
    {"from": "registry", "to": "drive", "label": "EXCEL", "style": "link", "dashed": true},
    {"from": "drive", "to": "portal", "label": "PUBLISH", "style": "accent"}
  ],
  "crosscuts": [{"id": "identity", "label": "Identity Manager", "detail": "AD · LDAP · SSO"}]
}
```

For direct JSON library use, keep the input data-driven and return the diagram
after writing it:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('it-state.json'))
File.write('it-state.svg', diagram.to_svg)
diagram
```

The model has `phase(id, label)`, nested `system(id, label, detail:, state:)`,
top-level `handoff(from, to, label, style:, dashed:)`, and
`crosscut(id, label, detail:)`. Phase labels are optional and default to the
uppercase humanized ID; system and crosscut labels are optional and default to
a humanized ID. System `detail` and crosscut `detail` are optional and default
to `nil`. System state is `standard`, `external`, or `pain_point`; omitted state
is `standard`. Handoff style is `neutral`, `link`, or `accent`; omitted style
is `neutral`, and omitted `dashed` is `false`. At the diagram level, `title`
defaults to `Diagram`, `direction` to horizontal `:right`, `theme` to `:light`,
and `style` to `:editorial`; `subtitle` and `eyebrow` are optional presentation
text. A pain-point system
makes every touching handoff accent, regardless of its requested style. A
dashed handoff draws a dashed line; there is no `manual` field and code must
not infer an independent medium or external meaning from `dashed`.
The renderer adds a curated legend for semantics used in the diagram; crosscut
footer bars have no graph endpoints.

Strict JSON uses the same fields under `phases[].systems`, plus `handoffs` and
`crosscuts` at the top level. Render it with `slimgraph render it-state.json -o
it-state.svg`, `slimgraph render it-state.rb -o it-state.svg`, or pipe JSON to
`slimgraph render - -o it-state.svg`. For library
use, call `SlimGraphR::Document.from_json(File.read('it-state.json')).to_svg`.
The Ruby CLI example returns `diagram` after `File.write`; this keeps it
executable when supplied to the CLI. JSON is consumed as validated data. In
StreamWeaver, load
`slim_graph_r/stream_weaver` and use `diagram :it_state, ... do ... end`; the
adapter is optional and the core renderer has no runtime dependency on it.

Use two to four phases, one to five systems per phase, and at most 16 systems,
24 handoffs, two pain points, and three crosscuts. Phase labels are uppercase
and at most 14 characters; handoff labels are uppercase and at most eight.
IDs are globally unique, references must exist, and self-handoffs, duplicate
IDs, unknown fields, invalid enum values, and non-boolean `dashed` values are
errors. Source order defines forward versus backward. A backward handoff must
touch an external system and set `dashed: true`. This backward handoff is
invalid because it is not dashed:

```ruby
handoff :portal, :registry, 'REWORK', style: :link, dashed: false
```

Unplaceable routes or labels raise
`LayoutError` instead of crossing systems or hiding text. Vertical layout,
icons, custom colors, side overrides, caller legends, and full editorial
framing are outside this slice. A supplied top-level `description` replaces the
generated accessible description; when it is absent, the renderer generates
one from the phases, systems, handoffs, and crosscuts.

This bounded type is an independent implementation inspired by and credited to
[Cathryn Lavery's Diagram Design](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-it-state.md).
