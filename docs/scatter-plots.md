# Scatter plots

Scatter plots position 2–30 complete observations using two continuous quantities. Both units and both finite linear scales are required and must contain every point.

```ruby
SlimGraphR.diagram(:scatter, title: 'Latency and errors', x_unit: 'ms', y_unit: '%') do
  x_scale min: -100, max: 600
  y_scale min: -1, max: 8
  point :payments, 'Payments', x: 260, y: 2.8, focal: true, annotate: true
  point :search, 'Search', x: 90, y: 0
end
```

One point may be focal and at most three may be annotated. Position is the only encoding. Bubble size, a third variable, trend lines, regression, jitter, quadrants, snapping, clipping, and missing-value repair are outside this contract. Negative and zero coordinates map exactly. Explicit scale bounds and units remain visible and accessible.

Use `anonymous_point x:, y:` only for observations whose identities are intentionally unavailable. Anonymous marks cannot be focal or annotated and emit no synthetic ID or label. Strict JSON represents one as `{"anonymous":true,"x":8,"y":12}`. The generated chart description reports anonymous-mark count and x/y ranges, alongside any named focal point.

See the paired executable [Ruby](../examples/standalone/scatter.rb) and [JSON](../examples/standalone/scatter.json) inputs.
