# Dependency graphs

A dependency graph shows what depends on what when a tree would lose the meaning. Use it for a shared requirement (several nodes converge on one dependency) or for a real cycle. If every node has one parent and there is no cycle, use `:tree` with nested `root`/`child` blocks; see the [Tree guide](trees.md) for its input schema.

## Standalone Ruby

Require the core gem and build a `:dependency` diagram with `SlimGraphR.diagram`. `dependency` declares an internal package, module, or service. `external_dependency` declares a third-party requirement and requires both `version:` and `registry:`. `depends_on dependent, requirement` draws an arrow from the dependent to the requirement.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :dependency,
  title: 'Runtime dependencies',
  style: :editorial,
  theme: :light do
  dependency :app, 'Application'
  dependency :worker, 'Worker'
  dependency :core, 'Shared core'
  external_dependency :rack, 'Rack', version: '3.2.1', registry: 'RubyGems'

  depends_on :app, :core
  depends_on :worker, :core
  depends_on :core, :rack
end

File.write('dependencies.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the CLI.
```

The arrow direction is deliberate: `depends_on :app, :core` reads “Application depends on Shared core.” IDs are stable references; labels are what readers see. A node with no outgoing relationship is a leaf. Every node receives a computed fan-in badge such as `2 in`, including `0 in` for entry points with no dependents. The shared dependency therefore remains visible in the picture instead of becoming an unlabeled convergence.

Mark one relationship with `cycle: true` only when it closes a real cycle:

```ruby
depends_on :cycle_bridge, :app, cycle: true
```

The marked relationship is the only upward back-edge. Removing it must leave an acyclic graph, and the remaining relationships must contain a path from its requirement back to its dependent. Unmarked cycles and tree-shaped input fail with an actionable error. A cycle is optional when a shared dependency already gives the graph its meaning.

Validation is explicit:

```ruby
# One-parent branching data: use :tree with nested root/child blocks.
SlimGraphR.diagram(:dependency) do
  dependency :app
  dependency :core
  dependency :leaf
  depends_on :app, :core
  depends_on :core, :leaf
end

# A marked edge must close a real cycle.
SlimGraphR.diagram(:dependency) do
  dependency :app
  dependency :core
  dependency :other
  depends_on :app, :core
  depends_on :other, :app, cycle: true # raises: marked edge does not close a path
end

# External metadata is required.
SlimGraphR.diagram(:dependency) do
  external_dependency :rack, 'Rack', version: '3.2.1' # raises: registry is required
end
```

## Equivalent strict JSON

JSON uses `nodes` and `edges`, but only the dependency fields are accepted for this type. Internal nodes require `id` and may provide `label`. External nodes use `kind: "external"` and must provide nonblank `version` and `registry`. Edges use `from` for the dependent, `to` for the requirement, and an optional boolean `cycle`.

```json
{
  "type": "dependency",
  "title": "Runtime dependencies",
  "nodes": [
    {"id": "app", "label": "Application"},
    {"id": "worker", "label": "Worker"},
    {"id": "core", "label": "Shared core"},
    {"id": "rack", "label": "Rack", "kind": "external", "version": "3.2.1", "registry": "RubyGems"}
  ],
  "edges": [
    {"from": "app", "to": "core"},
    {"from": "worker", "to": "core"},
    {"from": "core", "to": "rack"}
  ]
}
```

Parse the same model from Ruby:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('dependencies.json'))
File.write('dependencies.svg', diagram.to_svg)
diagram
```

The parser is strict and never evaluates JSON as Ruby. Unknown fields, generic graph helpers, missing references, duplicate relationships, non-boolean `cycle`, incomplete external metadata, and cross-type fields raise `SlimGraphR::Error`.

## CLI

The CLI selects JSON from the `.json` extension and Ruby from `.rb`:

```sh
slimgraph render dependencies.rb -o dependencies.svg
slimgraph render dependencies.json -o dependencies.html --format html
```

For stdin, JSON is the default; use `--input-format ruby` for Ruby source. A Ruby document must return the diagram as its final expression, so place `diagram` after `File.write` when the example also saves a file. `--style` and `--theme` override presentation without changing the model.

## Layout and limits

Dependency graphs use a downward ranked layout. Rank rows are 120px apart; nodes are fixed 160×56px boxes. Internal nodes use the normal package treatment, external nodes show their version and registry with an external treatment, and leaves use a muted leaf treatment unless the node is external, in which case the external treatment takes precedence. The one marked cycle uses an outside dashed accent lane and a `CYCLE` label. Its endpoint nodes keep their ordinary treatments.

The bounded slice allows at most 9 nodes, 14 relationships, 5 ranks, one marked cycle, and two accent elements (the cycle edge and its label). Dense rank pairs expand their measured inter-rank routing band; long routes claim lanes before local routes, and perpendicular crossings use bridges. It does not accept groups, emphasis, arbitrary generic labels, or coordinates. These limits bound the layout but do not guarantee that every topology or label will fit. Ordinary dependency paths cannot double back upward; congestion or a connector or label that cannot be placed without crossing a non-endpoint node or obscuring content raises `SlimGraphR::LayoutError`. Shorten labels or split the graph. Inspect a real rendered page at its intended width, including a narrow container.

This is bounded partial parity with the pinned [Cathryn Lavery Diagram Design dependency reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-dependency.md). SlimGraphR is an independent Ruby implementation. The core renderer depends only on the extracted standard-library `bigdecimal` and `ostruct` gems; StreamWeaver integration remains optional and is loaded with `require 'slim_graph_r/stream_weaver'`. Upstream attribution and the MIT notice remain in `vendor/diagram-design`.
