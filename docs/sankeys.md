# Sankey diagrams

Sankey diagrams encode a conserved quantity through exactly three declared stages. SlimGraphR accepts 3–10 strictly positive nodes and 2–16 strictly positive adjacent-stage flows. Every first-stage node equals its outgoing sum, every middle node equals both incoming and outgoing sums, every final node equals its incoming sum, and all stage totals must match exactly after accepted numbers become `BigDecimal`.

```ruby
SlimGraphR.diagram(:sankey, title: 'CI minutes', unit: 'minutes') do
  stage :source, 'Input'; stage :work, 'Work'; stage :outcome, 'Outcome'
  node :ci, stage: :source, label: 'CI', value: 100
  node :test, stage: :work, label: 'Test', value: 60
  node :build, stage: :work, label: 'Build', value: 40
  node :passed, stage: :outcome, label: 'Passed', value: 90
  node :waste, stage: :outcome, label: 'Waste', value: 10
  flow :ci, :test, 60; flow :ci, :build, 40
  flow :test, :passed, 55; flow :test, :waste, 5
  flow :build, :passed, 35; flow :build, :waste, 5
end
```

One finite layout-selected `px_per_unit` drives every node height and ribbon thickness without snapping, rounding, flooring, or per-column repair. Each ribbon owns disjoint source and target offset intervals and meets both bars horizontally. If the smallest band would render below one device pixel, layout fails with an aggregation-or-split remedy. Real loss must be an explicit final node such as Waste; SlimGraphR never infers loss, remainder, efficiency, injection, or `Other`.

JSON allows only the common quantitative fields plus `unit`, optional `balance: "strict"`, `stages`, `nodes`, and `flows`. See [sankey.json](../examples/standalone/sankey.json).

One or two authored flows may set `focal: true`. The renderer accents only those ribbons, includes them in the legend, and repeats their endpoints and quantities in the generated description. A focal flow is an author-selected discussion claim; it is never inferred from value or position.

The editorial direction is adapted from Cathryn Lavery's pinned Diagram Design Sankey reference under the vendored MIT notice. This bounded implementation is partial parity; no upstream variant is yet fully verified.
