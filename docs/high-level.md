# High-level data stack diagrams

Use `:high_level` for a compact end-to-end data platform: external sources, processing phases, a clustered component boundary, and the services that operate across it. It is a dedicated diagram type, with its own bounded grammar; it is not an alias for `:architecture` or `:it_state`.

## Standalone Ruby

Build the model with nested `phase` blocks. The first phase contains sources only. Later phases contain one or more components. `connect` takes two IDs and creates an unlabeled forward data link. Mark exactly one component with `focal: true`.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :high_level, title: 'National data platform' do
  phase :sources, 'Data sources' do
    source :postgres, 'PostgreSQL', type: :db, detail: 'Registry'
  end

  phase :ingest, 'Ingestion' do
    component :nifi, 'NiFi', role: 'COLL'
  end

  phase :storage, 'Storage' do
    component :minio, 'MinIO', role: 'STORE', focal: true
  end

  phase :visualize, 'Visualization' do
    component :superset, 'Superset', role: 'DASH'
  end

  connect :postgres, :nifi
  connect :nifi, :minio
  connect :minio, :superset
  orchestrate :airflow, 'Airflow', detail: 'Apache Airflow', targets: %i[nifi superset]
  crosscut :identity, 'Identity', detail: 'LDAP · OIDC', concern: 'Security'
end

File.write('high-level.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

`cluster:` is an optional diagram label and defaults to `Cluster`; the renderer does not infer or invent a platform name. Phase labels and vertical concern labels are uppercased for their chevrons and measured against their available width; source labels, component labels, roles, details, and concerns are also measured text. `columns:` is optional on a phase and defaults to one column. A phase may declare one or two columns, with five columns total at most. IDs are references, not visible labels unless a label is omitted; omitted labels are humanized from the ID. Source and component labels are optional in both Ruby and JSON; component `role` is required and defaults are not invented for it.

`orchestrate` adds one bar inside the cluster. Its concern defaults to `Orchestration`. `targets:` is nonempty, names existing components, and may include the focal component, but each target must be the top component in its phase; a lower stacked target would be hidden by a straight trigger drop and is rejected. A bar-to-focal link keeps trigger styling because bar-originating trigger semantics take precedence; other data links touching the focal component receive the focal `primary` treatment automatically, while ordinary source/component links use `secondary`. `crosscut` adds a footer row with no graph endpoints. Its `concern:` is required and distinct for each crosscut. The renderer creates the matching vertical concern chevron automatically, so authors do not provide a vertical list.

## Equivalent strict JSON

JSON uses `phases`, `connections`, optional `orchestration`, and optional `crosscuts`. A phase has `id`, optional `label`, optional `columns`, and `sources`/`components` arrays. Sources require `id` and a `type` from `db`, `ftp`, `web`, `legacy`, or `api`; `label` and `detail` are optional, and source labels default from their IDs. Components require `id` and nonblank `role`; `label` and `detail` are optional, `role` is limited to eight characters, and boolean `focal` defaults to `false`. Connections contain only `from` and `to` in this first slice.

```json
{
  "type": "high_level",
  "title": "National data platform",
  "phases": [
    {"id": "sources", "label": "Data sources", "sources": [
      {"id": "postgres", "label": "PostgreSQL", "type": "db", "detail": "Registry"}
    ], "components": []},
    {"id": "ingest", "label": "Ingestion", "sources": [], "components": [
      {"id": "nifi", "label": "NiFi", "role": "COLL"}
    ]},
    {"id": "storage", "label": "Storage", "sources": [], "components": [
      {"id": "minio", "label": "MinIO", "role": "STORE", "focal": true}
    ]},
    {"id": "visualize", "label": "Visualization", "sources": [], "components": [
      {"id": "superset", "label": "Superset", "role": "DASH"}
    ]}
  ],
  "connections": [
    {"from": "postgres", "to": "nifi"},
    {"from": "nifi", "to": "minio"},
    {"from": "minio", "to": "superset"}
  ],
  "orchestration": {
    "id": "airflow",
    "label": "Airflow",
    "detail": "Apache Airflow",
    "targets": ["nifi", "superset"]
  },
  "crosscuts": [
    {"id": "identity", "label": "Identity", "detail": "LDAP · OIDC", "concern": "Security"}
  ]
}
```

The library path is explicit:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('high-level.json'))
File.write('high-level.svg', diagram.to_svg)
diagram
```

Unknown keys, nulls, wrong types, blank required text, duplicate IDs, missing references, and fields belonging to another diagram type are errors. Source `type` remains semantic data in the model and accessible description even though source icons are outside this slice. The generated accessible description reports effective `secondary`, `primary`, and `trigger` data-path styles and the source type; supplying `description:` replaces that generated description.

## CLI and StreamWeaver

The CLI accepts either form:

```sh
slimgraph render high-level.rb -o high-level.svg
slimgraph render high-level.json -o high-level.svg
cat high-level.json | slimgraph render - -o high-level.svg
```

JSON is the stdin default. Use `--input-format ruby` for Ruby source from stdin. `--style` and `--theme` remain presentation overrides; `:light`, `:dark`, and `:auto` modes and all named styles continue to work. Ruby CLI files must return the diagram after any `File.write`, as shown above. The core renderer depends only on the extracted standard-library `bigdecimal` and `ostruct` gems. StreamWeaver is optional: load `slim_graph_r/stream_weaver` and use the same `diagram :high_level, ... do` body in a StreamWeaver document.

## Limits and failure behavior

The bounded 0.11 slice allows:

| Input | Limit |
| --- | ---: |
| Horizontal phases | 3–5 |
| Sources in the first phase | 1–4 |
| Components in each later phase | 1–2 |
| Total components | 8 |
| Data connections | 12 |
| Outgoing connections from one node | 3 |
| Phase columns | 1–2 each, 5 total |
| Orchestration bars | 0–1 |
| Crosscuts | 0–2 |
| Explicit focal components | exactly 1 |

Data links must advance from an earlier phase to a later phase. Same-phase, backward, query/read-back, and authored edge-label connections fail validation in this release. Reserved concern labels such as `Orchestration`, `Security`, `Observability`, `Governance`, and `Backup` cannot be used as horizontal phase labels. The renderer reserves a 28px right strip when orchestration or crosscut concerns are present; phase centers and 152×80 component boxes remain aligned to the phase chevrons. Phase and vertical concern labels are uppercased for display and rejected when their measured text does not fit. If measured text, ports, routes, or concern pairing cannot fit faithfully, it raises `SlimGraphR::LayoutError` instead of clipping or silently changing meaning.

Icons, custom colors, manually authored vertical concerns, query/backward links, same-phase links, edge labels, side overrides, unclustered layouts, and editorial-card variants are outside this bounded slice. The model keeps light/dark/auto themes, accessible title/description output, and deterministic geometry. A rendered SVG is evidence of serialization, not a claim of full upstream parity; this remains a partial implementation against the pinned [Cathryn Lavery Diagram Design high-level reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-high-level.md). SlimGraphR is an independent Ruby implementation and retains the upstream MIT notice in `vendor/diagram-design`.
