# Tree and hierarchy diagrams

Use `:tree` for a branching hierarchy: service ownership, a taxonomy, a file tree, or a decision breakdown. Each non-root node has one direct structural parent. Use `:nested` when the meaning is containment, and `:layers` when the levels are parallel bands in an ordered stack.

## Standalone Ruby

The DSL is nested: `root` opens the one root node and `child` adds a direct child in the current node's block. IDs are stable references; labels are reader-facing text. `detail` is an optional second line. `focal: true` may mark at most one node, and a tree with no focal node is valid.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :tree,
  title: 'Service ownership',
  direction: :down,
  style: :editorial,
  theme: :light do
  root :platform, 'Platform', detail: 'Shared foundation', focal: false do
    child :product, 'Product', focal: false do
      child :api, 'API', detail: 'Public boundary', focal: true
    end
    child :operations, 'Operations', focal: false
  end
end

File.write('service-ownership.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

`direction: :right` is useful for a wide hierarchy; the default is `:down`. The model is immutable after construction. `to_svg` returns portable SVG and `to_html` returns a self-contained page. Labels and details are measured before placement, so content is not silently clipped. An unplaceable tree raises `SlimGraphR::LayoutError` with guidance to shorten text or split the hierarchy.

## Equivalent strict JSON

JSON uses one recursive `root` object. Each node has a required `id`, optional `label`, optional `detail`, optional boolean `focal`, and an optional `children` array. Omitted `children` means a leaf. Omitted labels derive from IDs and omitted focal values are false. The JSON below matches the Ruby example's metadata and content.

```json
{
  "type": "tree",
  "title": "Service ownership",
  "direction": "down",
  "style": "editorial",
  "theme": "light",
  "root": {
    "id": "platform",
    "label": "Platform",
    "detail": "Shared foundation",
    "focal": false,
    "children": [
      {
        "id": "product",
        "label": "Product",
        "focal": false,
        "children": [
          {
            "id": "api",
            "label": "API",
            "detail": "Public boundary",
            "focal": true
          }
        ]
      },
      {"id": "operations", "label": "Operations", "focal": false}
    ]
  }
}
```

Load JSON through the same validated model:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('service-ownership.json'))
File.write('service-ownership.svg', diagram.to_svg)
diagram
```

The parser validates data and never evaluates JSON as Ruby. Explicit nulls, unknown fields, generic or cross-type fields, malformed children, duplicate IDs, and a second focal node raise `SlimGraphR::Error`. The optional top-level `description` replaces the generated accessible description.

## CLI and StreamWeaver

```sh
slimgraph render service-ownership.rb -o service-ownership.svg
slimgraph render service-ownership.json -o service-ownership.html --format html
```

JSON is the default for stdin; use `--input-format ruby` for Ruby stdin. `--style` and `--theme` override presentation without changing the model.

StreamWeaver is optional and loaded explicitly:

```ruby
require 'slim_graph_r/stream_weaver'

diagram :tree, title: 'Service ownership', direction: :down, style: :editorial, theme: :light do
  root :platform, 'Platform', detail: 'Shared foundation', focal: false do
    child :product, 'Product', focal: false do
      child :api, 'API', detail: 'Public boundary', focal: true
    end
    child :operations, 'Operations', focal: false
  end
end
```

The core renderer depends only on the extracted standard-library `bigdecimal` and `ostruct` gems. Verify a real rendered page at its target and narrow widths; an SVG string or canvas push alone does not prove the browser page works.

## Layout, limits, and parity boundary

Connectors are drawn behind nodes as an orthogonal parent stem, sibling bus, and child drops. Nodes are rounded rectangles with measured widths between 120 and 180px and heights of 40 or 52px depending on detail. Focal treatment uses the style accent and tint; leaves use the leaf treatment when they are not focal.

The bounded slice permits depth 1–4 including the root, at most five nodes in any tier, and at most five direct children for a parent. Exactly one root is required. IDs are globally unique, and skipped levels are rejected rather than inferred. The tree scene is bounded at 1140px. Coordinates and arbitrary edge collections are outside this DSL.

This is partial parity with the pinned [Cathryn Lavery Diagram Design tree reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-tree.md). It does not claim complete upstream parity. Leaf indicators beyond the built-in treatment, icons, summary cards, alternate annotations, and unrestricted-depth trees remain deferred. Upstream attribution and the MIT notice remain under `vendor/diagram-design`.
