# Platform-integration diagrams

A platform-integration diagram answers one bounded question: which declared
surface connects to a platform, and by which declared protocol? Use
`:dp_integration` for a bounded platform zone with sources, platform services,
consumers, layer-wide services, and explicit integration wires. It describes
declared integration boundaries; it does not infer data paths, permissions,
protocols, or policy from names or proximity.

## Standalone Ruby

Build the 0.18 model with `source`, one `platform` block containing one
`row` and optional `bar`s, `consumer`, `layer_service`, and `wire`. Sources
accept exactly one kind from `:database`, `:file_drop`, `:mail`, or `:legacy`.
Consumers use `:analytics`, `:web`, or `:api`; layer services use `:identity`,
`:observability`, `:backup`, or `:secrets`. Details are literal optional text.
IDs are required. Source, consumer, layer-service, bar, and service labels are
optional and default to a cleaned humanized ID when omitted; a supplied label
is literal cleaned text, and blank or `null` labels are rejected. The platform
has no ID, so its label is required.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :dp_integration,
  title: 'Declared platform · surfaces' do
  source :warehouse, 'Warehouse', kind: :database, detail: 'SQL'
  source :drop, 'Partner drop', kind: :file_drop, detail: 'SFTP'

  platform 'Data platform' do
    bar :query, 'Query service', role: 'SQL', focal: true, serves: true
    row do
      service :ingest, 'Ingest', role: 'INGEST', detail: 'ETL'
      service :store, 'Object store', role: 'STORE', detail: 'Objects', focal: true
      service :notebook, 'Notebook', role: 'ANALYSE'
    end
    bar :schedule, 'Scheduler', role: 'DAG'
  end

  consumer :reports, 'Reports', kind: :analytics, detail: 'ODBC'
  consumer :portal, 'Public portal', kind: :web, detail: 'HTTPS'
  layer_service :identity, 'Identity', kind: :identity, protocol: 'AUTH'

  wire :warehouse, :query, kind: :federated, protocol: 'JDBC'
  wire :drop, :ingest, kind: :ordinary, protocol: 'SFTP'
  wire :ingest, :store, kind: :ordinary, protocol: 'WRITE'
  wire :schedule, :ingest, kind: :trigger
  wire :query, :reports, kind: :serve, protocol: 'ODBC'
  wire :query, :portal, kind: :serve, protocol: 'HTTPS'
end

File.write('platform-integrations.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

The platform appears once. Its declaration order is retained: zero to two
full-width `bar`s may surround exactly one `row`, and a row contains two to
four `service`s. A bar or service may carry literal optional `role:` or
`detail:` text and may be focal; only one platform component may declare
`serves: true`. The bounded model requires exactly two focal platform
components. Every ID is globally unique.

The fixture above has two sources, three platform bands (`bar`, `row`, `bar`),
five platform components, two consumers, one layer service, and six wires. It
uses exactly two focal components (`query` and `store`) and exactly one
serving component (`query`); the topology is source→platform twice,
platform→platform once, bar-trigger→service once, and serving-platform→consumer
twice.

`wire` is the only integration edge and names declared endpoints. Its kind is
exactly `:ordinary`, `:federated`, `:trigger`, or `:serve`. Source-to-platform
and platform-to-platform wires are ordinary or federated. A trigger is an
internal control wire from a bar and has no label or protocol. A platform to
consumer wire is `:serve`, requires the one serving component as its origin,
and requires a literal protocol. Every non-trigger wire requires a literal
protocol; an internal wire from a bar must be that bar-originating trigger. No
endpoint role, protocol, edge, or conversion is inferred.

`layer_service` records an external service for the whole platform layer. Its
literal protocol is drawn to a platform-boundary port, never to a component;
there is no direct layer-service wire and no component-level policy claim.
The boundary attachment records the declared layer scope only.

## Equivalent strict JSON

JSON mirrors the Ruby containment instead of accepting generic `nodes` or
`edges`. Every platform row is an object with `kind` and an `items` array;
`kind: "row"` carries the row's services and `kind: "bar"` carries its bar
component.

```json
{
  "type": "dp_integration",
  "title": "Declared platform · surfaces",
  "sources": [
    {"id": "warehouse", "label": "Warehouse", "kind": "database", "detail": "SQL"},
    {"id": "drop", "label": "Partner drop", "kind": "file_drop", "detail": "SFTP"}
  ],
  "platform": {
    "label": "Data platform",
    "rows": [
      {"kind": "bar", "items": [
        {"id": "query", "label": "Query service", "role": "SQL", "focal": true, "serves": true}
      ]},
      {"kind": "row", "items": [
        {"id": "ingest", "label": "Ingest", "role": "INGEST", "detail": "ETL"},
        {"id": "store", "label": "Object store", "role": "STORE", "detail": "Objects", "focal": true},
        {"id": "notebook", "label": "Notebook", "role": "ANALYSE"}
      ]},
      {"kind": "bar", "items": [
        {"id": "schedule", "label": "Scheduler", "role": "DAG"}
      ]}
    ]
  },
  "consumers": [
    {"id": "reports", "label": "Reports", "kind": "analytics", "detail": "ODBC"},
    {"id": "portal", "label": "Public portal", "kind": "web", "detail": "HTTPS"}
  ],
  "layer_services": [
    {"id": "identity", "label": "Identity", "kind": "identity", "protocol": "AUTH"}
  ],
  "wires": [
    {"from": "warehouse", "to": "query", "kind": "federated", "protocol": "JDBC"},
    {"from": "drop", "to": "ingest", "kind": "ordinary", "protocol": "SFTP"},
    {"from": "ingest", "to": "store", "kind": "ordinary", "protocol": "WRITE"},
    {"from": "schedule", "to": "ingest", "kind": "trigger"},
    {"from": "query", "to": "reports", "kind": "serve", "protocol": "ODBC"},
    {"from": "query", "to": "portal", "kind": "serve", "protocol": "HTTPS"}
  ]
}
```

Parse the same model directly from a file:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('platform-integrations.json'))
File.write('platform-integrations.svg', diagram.to_svg)
diagram
```

The strict root is `{type,title,description,style,theme,sources,platform,
consumers,layer_services,wires}`. A source or consumer is
`{id,label,kind,detail}`. Platform rows are `{kind,items}`; a row's items and
a bar's single item use `{id,label,role,detail,focal,serves}`. A layer service
is `{id,label,kind,detail,protocol}` and a wire is
`{from,to,kind,protocol}`. Optional scalar fields are omitted, never `null`;
`focal` and `serves` default to `false` only when omitted.

The parser rejects unknown, cross-type, null, wrong-type, blank, duplicate,
unresolved, or over-budget values; invalid enum members; duplicate platform
IDs; malformed row containment; direct layer-service wires; and protocols on
triggers. It rejects direct source/consumer shortcuts, arbitrary colours or
SVG icons, coordinates, and generic graph methods. Missing protocol on a
non-trigger is an error, as is a serve wire from any component other than the
one declared serving component. Ruby and JSON therefore make the same
explicit integration claims.

The optional document `description` is literal accessible text. Supplying
`description: 'Exact author description'` in Ruby or
`"description": "Exact author description"` in JSON replaces the generated
description; it does not add an inferred edge or alter the declared model.

## CLI and optional StreamWeaver

Use these command forms when the 0.18 renderer is ready:

```sh
ruby -Ilib exe/slimgraph render platform-integrations.rb -o platform-integrations.svg
ruby -Ilib exe/slimgraph render platform-integrations.json -o platform-integrations.svg
slimgraph render platform-integrations.json -o platform-integrations-installed.svg
```

The file extension selects Ruby or JSON. JSON is the stdin default; use
`--input-format ruby` for Ruby source from stdin. A Ruby CLI document must
leave `diagram` as its final expression. `--style` and `--theme` override
presentation only. The direct library parser remains
`SlimGraphR::Document.from_json(File.read(...))`.

StreamWeaver is optional and must be loaded explicitly:

```ruby
require 'slim_graph_r/stream_weaver'

# Use the same SlimGraphR.diagram(:dp_integration, ...) block above.
```

The core renderer has no runtime dependency on StreamWeaver. This guide
documents the 0.18 contract; the model/parser API and standalone fixture are
stable, and the shipped renderer has passed focused geometry and browser gates.

## Layout, accessibility, limits, and failure behavior

Render a measured read surface with one bordered platform zone. Sources and
consumers use 160×64px side cards that expand in measured 4px increments up to
208px when literal detail, kind, or a two-line title requires it. The surface
adds protocol corridor lanes when those expanded cards need route-label
clearance. The zone's single row anchors its content; bars reserve
full-width horizontal strips above or below it. The masked zone label marks a
visual boundary, not a node. Layer services use one measured footer-card strip
outside the zone.

All wires route orthogonally through reserved side and internal corridors.
Fan-out ports and separated lanes keep routes distinct. Non-trigger protocol
labels use a measured monospace role, paper mask, and at least 8px path
clearance; triggers remain unlabelled. Ordinary wires use the neutral wire
treatment regardless of endpoint role. Layer-service attachments terminate at
distinct platform-boundary ports. Connectors cannot cross, overlap another
path, hide behind an unrelated card, or attach to a component when the
declaration is layer-wide. If the zone cannot contain the bands, routes or
ports cannot stay distinct, a protocol label cannot clear its path, or
footer/legend text does not fit, raise `SlimGraphR::LayoutError`. Shorten
labels or split the diagram; never clip, move, aggregate, or invent content to
make it fit.

The bounded release allows 0–6 sources, 0–6 consumers, 2–6 platform
components, 0–3 layer services, and at most 20 wires. It requires at least one
source or consumer and one wire, exactly two focal components, and exactly one
serving component. Labels, roles, details, protocols, and the platform label
are measured text and must fit their reserved lanes. Row cards begin at 160px
and expand to 208px; a row grows from 72px to at most 120px when endpoint or
serving-detail lanes require clearance. The generated accessible
description enumerates sources, platform bands and components with focal and
serving roles, consumers, layer services and their protocols, then every wire.
Supplying `description:` on the document replaces that generated description
with the author's literal accessible description; it does not add inferred
relationships or change the model.

This is bounded partial parity with the pinned [Cathryn Lavery Diagram Design
DP-integration reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-dp-integration.md).
SlimGraphR is an independent Ruby implementation. Upstream attribution and
the MIT notice remain in `vendor/diagram-design`; arbitrary third-party icons,
arbitrary colours, multiple platform zones, extra rows/bars, automatic
protocol discovery, direct footer/component links, arbitrary connector paths,
network imports, and full upstream decorative framing remain deferred.
