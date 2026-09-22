# Deployment diagrams

A deployment diagram shows where software runs: infrastructure nodes inside meaningful environment or network zones, the versioned artifacts on those nodes, and the protocol and port used by each network path. Use it when placement, replication, or an installed version matters. If the picture only explains logical components and relationships, use `:architecture`.

## Standalone Ruby

Require the core gem and build a `:deployment` diagram with `SlimGraphR.diagram`. A deployment has three containment levels: `zone` contains an infrastructure node, and that node contains one or more versioned artifact chips. Infrastructure constructors are `host`, `vm`, `pod`, `managed`, and `cdn`. Each takes an ID, an optional label, optional `replicas:` and `emphasis:`, and a block of artifacts. Omitted labels become readable names from their IDs. `replicas:` defaults to `1` and must be a positive integer. `emphasis:` is a strict boolean and may be used on a node or path.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :deployment,
  title: 'Production placement', style: :editorial, theme: :light do
  zone :edge, 'Edge' do
    cdn :front_door, 'Global CDN', replicas: 2 do
      artifact 'storefront', version: '2026.09.1'
    end
  end

  zone :prod, 'Production / eu-west-1' do
    pod :api, 'API pods', replicas: 3 do
      artifact 'api', version: 'v2.4.1'
      artifact 'otel sidecar', version: '0.109.0'
    end
    managed :primary, 'RDS primary', emphasis: true do
      artifact 'postgres', version: '16.4'
    end
  end

  network :front_door, :api, protocol: 'HTTPS', port: 443
  network :api, :primary, protocol: 'TLS', port: 5432, async: true
end

File.write('deployment.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

`artifact name, version:` requires a nonblank version. The artifact name is the chip's visible name and the version is retained as a separate version label. A node with two artifacts, such as the API pod above, represents co-location; replicas remain one node with an `xN` badge. IDs are stable references and must be unique across zones and nodes. `network from, to, protocol:, port:, async: false, emphasis: false` creates a top-level path between infrastructure IDs. `protocol` is nonblank text and `port` is an integer from 1 through 65,535; the rendered path label is generated as `PROTOCOL:port`.

The library returns the same immutable diagram model used by the CLI. Use `diagram.to_svg` for a standalone SVG or `diagram.to_html` for a self-contained HTML page. To load strict JSON in Ruby:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('deployment.json'))
File.write('deployment.svg', diagram.to_svg)
diagram
```

## Equivalent strict JSON

Deployment JSON uses `zones`, `nodes`, `artifacts`, and `paths`. It does not use generic top-level `nodes` or `edges` collections. Shared document options are `type`, `title`, `description`, `style`, and `theme`.

```json
{
  "type": "deployment",
  "title": "Production placement",
  "style": "editorial",
  "theme": "light",
  "zones": [
    {
      "id": "edge",
      "label": "Edge",
      "nodes": [
        {
          "id": "front_door",
          "label": "Global CDN",
          "kind": "cdn",
          "replicas": 2,
          "artifacts": [{"name": "storefront", "version": "2026.09.1"}]
        }
      ]
    },
    {
      "id": "prod",
      "label": "Production / eu-west-1",
      "nodes": [
        {
          "id": "api",
          "label": "API pods",
          "kind": "pod",
          "replicas": 3,
          "artifacts": [
            {"name": "api", "version": "v2.4.1"},
            {"name": "otel sidecar", "version": "0.109.0"}
          ]
        },
        {
          "id": "primary",
          "label": "RDS primary",
          "kind": "managed",
          "replicas": 1,
          "emphasis": true,
          "artifacts": [{"name": "postgres", "version": "16.4"}]
        }
      ]
    }
  ],
  "paths": [
    {"from": "front_door", "to": "api", "protocol": "HTTPS", "port": 443},
    {"from": "api", "to": "primary", "protocol": "TLS", "port": 5432, "async": true}
  ]
}
```

Each zone requires a nonblank `id` and at least one node; its optional `label` defaults from the ID. Each node requires a nonblank `id`, a `kind` from `host`, `vm`, `pod`, `managed`, or `cdn`, a positive integer `replicas` (default `1` when omitted), and at least one artifact; its optional `label` also defaults from the ID. Each artifact requires nonblank string `name` and `version`. A path requires `from`, `to`, nonblank `protocol`, and an integer `port` in the valid range; `async` and `emphasis` are optional booleans and default to `false`.

The parser rejects unknown, null, incorrectly typed, or blank required fields; blank supplied labels; duplicate zone or node IDs; duplicate paths; unknown endpoints; empty zones; nodes without artifacts; unversioned artifacts; nonpositive replica counts; invalid ports; and cross-type fields such as generic `nodes`, `edges`, `groups`, `events`, `states`, or `steps`. Ruby and JSON therefore reach the same validated model and renderer.

## CLI and StreamWeaver

The CLI chooses Ruby or JSON from the file extension:

```sh
slimgraph render deployment.rb -o deployment.svg
slimgraph render deployment.json -o deployment.html --format html
```

JSON is the default for stdin; use `--input-format ruby` for Ruby source from stdin. `--style` and `--theme` override presentation without changing the deployment model. A Ruby document must return its diagram as the final expression, so keep `diagram` after a `File.write` call as shown above. Exit status `0` means success; document, rendering, and I/O failures use status `1`; command-line usage errors use status `2`.

The core renderer depends only on the extracted standard-library `bigdecimal` and `ostruct` gems. StreamWeaver remains optional: a StreamWeaver document loads `require 'slim_graph_r/stream_weaver'` and uses the same `diagram :deployment, ... do` block form. The deployment model and strict validation stay in the core library; no StreamWeaver installation is needed for standalone Ruby or JSON rendering.

## Layout, limits, and failure behavior

Zones render as measured columns in declaration order with a reserved 40px header. Infrastructure nodes stack inside their actual zone. The renderer measures node labels and every artifact name/version pair, gives each node a rectangular type tag and an internal `xN` replica badge when `N > 1`, and renders artifact chips at 24px high with an 8px stack gap. Zone bounds derive from member boxes and contain each node, chip, and badge.

The orthogonal router treats infrastructure boxes and every zone-header mask as obstacles. Internal paths attach at top or bottom and use muted treatment. Cross-zone paths attach at left or right and use the style's distinct link role: link blue in Editorial and Ruby, a separate link shade in Blueprint, and an ink adaptation in Mono. `emphasis: true` overrides the ordinary node or path treatment with the accent role and counts toward the combined focal budget. An `async: true` path is dashed `5,4`. Every path receives a measured 8px `PROTOCOL:port` label with an 8px mask clearance from its own line and clear route geometry. Rendering order is background, zones, paths, path labels, nodes, chips, and badges, so zone labels cannot be crossed or hidden.

The bounded slice has these budgets:

| Limit | Maximum |
| --- | ---: |
| Zones | 3 |
| Infrastructure nodes | 6 |
| Artifact chips | 9 |
| Network paths | 8 |
| Emphasized nodes and paths combined | 2 |

These limits describe a fixed containment grammar and a faithful-layout boundary. A path or label that cannot be placed without crossing a blocked zone header, node, or other content raises `SlimGraphR::LayoutError`; content is not clipped or silently nudged into an ambiguous position. Split a dense deployment by environment or shorten labels. A zone must represent an actual environment or network boundary, and every artifact must remain versioned.

This is bounded, partial parity with the pinned [Cathryn Lavery Diagram Design deployment reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-deployment.md). SlimGraphR is an independent Ruby implementation and does not claim full upstream parity. Upstream attribution and the MIT notice remain in `vendor/diagram-design`.
