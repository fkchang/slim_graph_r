# Treemaps

Treemaps encode one nonnegative part-of-whole measure as rectangle area. SlimGraphR accepts 2–12 unique items, requires a unit and at least one positive value, and permits one focal border. The renderer partitions one 920×440 logical-pixel rectangle with an unsnapped squarified layout. For every positive item, cell area is exactly `value / sum(positive values)` before SVG decimal serialization.

```ruby
SlimGraphR.diagram(:treemap, title: 'Storage', unit: 'GiB') do
  item :images, 'Images', 80
  item :logs, 'Logs', 20, focal: true
  item :archive, 'Archive', 0
end
```

A zero item remains in the immutable model, legend, metadata, and accessible description but receives no cell. A tiny positive value keeps its exact area and moves its label to the keyed external legend when the cell cannot hold 14px body and 12px value text. SlimGraphR never adds minimum area, gutters, log scaling, stripes, dropped items, or an invented `Other`. Aggregate upstream under an explicit name and disclose it in `source_note` when needed.

JSON allows only the common quantitative fields plus `unit` and `items`; each item allows only `id`, `label`, numeric `value`, and boolean `focal`. See [treemap.json](../examples/standalone/treemap.json).

The editorial direction is adapted from Cathryn Lavery's pinned Diagram Design treemap reference under the vendored MIT notice. This bounded implementation is partial parity; no upstream variant is yet fully verified.
