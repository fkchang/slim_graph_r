# Layer stack diagrams

Use `:layers` for an ordered abstraction or context stack: OSI layers, a CSS cascade, a protocol stack, or a memory hierarchy. Each layer is a parallel horizontal band. Use `:nested` when one level encloses another and `:tree` when a level branches into children.

## Standalone Ruby

Declare layers in display order with `layer id, label, index:`. `index` is required and is shown in the left index column. `detail` is optional. Exactly one layer must be marked `focal: true`. `axis` labels the outside direction indicator and defaults to `"Abstraction"`; `indicator` defaults to `:up` and accepts `:up` or `:down`.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :layers,
  title: 'Protocol stack',
  axis: 'Abstraction',
  indicator: :up,
  style: :editorial,
  theme: :light do
  layer :application, 'Application', index: 'L4', detail: 'HTTP', focal: true
  layer :transport, 'Transport', index: 'L3', detail: 'TCP'
  layer :network, 'Network', index: 'L2', detail: 'IP'
  layer :link, 'Link', index: 'L1', detail: 'Ethernet'
end

File.write('protocol-stack.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

Declaration order is display order. The example uses consecutive `L4`, `L3`, `L2`, `L1`; a jump such as `L7`, `L4` silently omits layers and is rejected. The model is immutable after construction.

## Equivalent strict JSON

JSON uses top-level `axis`, `indicator`, and a `layers` array. Each layer requires `id` and `index`; `label`, `detail`, and `focal` are optional. Omitted labels derive from IDs and omitted focal values are false. The JSON below matches the Ruby example's metadata and content.

```json
{
  "type": "layers",
  "title": "Protocol stack",
  "axis": "Abstraction",
  "indicator": "up",
  "style": "editorial",
  "theme": "light",
  "layers": [
    {"id": "application", "label": "Application", "index": "L4", "detail": "HTTP", "focal": true},
    {"id": "transport", "label": "Transport", "index": "L3", "detail": "TCP"},
    {"id": "network", "label": "Network", "index": "L2", "detail": "IP"},
    {"id": "link", "label": "Link", "index": "L1", "detail": "Ethernet"}
  ]
}
```

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('protocol-stack.json'))
File.write('protocol-stack.svg', diagram.to_svg)
diagram
```

The strict parser rejects nulls, unknown or cross-type fields, duplicate IDs, missing `index`, blank required strings, non-boolean `focal`, and indicators other than `up` or `down`. Numeric indices, including `L4`, must form one contiguous ascending or descending sequence with steps of exactly one. Named semantic indices are allowed when all indices are unique; numeric and semantic forms cannot be mixed. A supplied `description` replaces the generated ordered-layer description.

## CLI and StreamWeaver

```sh
slimgraph render protocol-stack.rb -o protocol-stack.svg
slimgraph render protocol-stack.json -o protocol-stack.html --format html
```

JSON is the default for stdin; use `--input-format ruby` for Ruby stdin. `--style` and `--theme` override presentation while preserving the layer model.

```ruby
require 'slim_graph_r/stream_weaver'

diagram :layers, title: 'Protocol stack', axis: 'Abstraction', indicator: :up,
  style: :editorial, theme: :light do
  layer :application, 'Application', index: 'L4', detail: 'HTTP', focal: true
  layer :transport, 'Transport', index: 'L3', detail: 'TCP'
  layer :network, 'Network', index: 'L2', detail: 'IP'
  layer :link, 'Link', index: 'L1', detail: 'Ethernet'
end
```

The adapter is optional and loaded with `require 'slim_graph_r/stream_weaver'`; the core renderer has no runtime dependencies. Check a real page at its intended and narrow widths because an SVG string or canvas push does not establish browser-page correctness.

## Layout, limits, and parity boundary

Bands share one measured width between 800 and 880px and equal 64px heights. Index, layer name, and detail columns run left to right. Hairline separators preserve the stack's reading order. The direction arrow sits outside the left edge with the axis label. Only the focal layer receives accent/tint styling.

The bounded model accepts 4–6 author-ordered layers, globally unique IDs, nonblank labels and indices, optional details, exactly one explicit focal layer, and `indicator: :up` or `:down`. Numeric indices must be contiguous by one with no silent gaps; unique named semantic indices are the alternative. Labels wider than the bounded 880px stack raise `SlimGraphR::LayoutError` rather than clipping. Arbitrary coordinates, connectors, mixed-height bands, multiple focal layers, and implicit missing layers are outside the contract.

This is partial parity with the pinned [Cathryn Lavery Diagram Design layer-stack reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-layers.md). It does not claim complete upstream OSI coverage or full editorial parity. Icons, variable-height layers, alternate annotations, gradients, and unrestricted stack variants remain deferred. Upstream attribution and the MIT notice remain under `vendor/diagram-design`.
