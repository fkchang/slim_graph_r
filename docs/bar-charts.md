# Bar charts

Bar charts compare one quantity across 2–12 ordered categories. Vertical is the default; choose `orientation: :horizontal` explicitly for long labels. One category may be focal.

```ruby
SlimGraphR.diagram(:bar, title: 'Net bookings', unit: 'USD millions') do
  scale min: -10, max: 30
  category :north, 'North', 24
  category :south, 'South', -6
  category :online, 'Online', 0, focal: true
end
```

The scale is linear and must contain every value and zero. Auto scale contains zero. Constant data uses a visible reference domain: all zero is `[-1,1]`, positive `c` is `[0,c+1]`, and negative `c` is `[c-1,0]`. Positive and negative bars start at exact zero; zero produces a label and accessible datum with no rectangle. There is no stacking, grouping, logarithmic scale, clipping, snapping, or fake minimum mark.

Values accept exactly finite `Integer`, `Float`, or `BigDecimal`. `precision:` is 0–6 (default 3), round-half-even, plain notation. See the paired executable [Ruby](../examples/standalone/bar.rb) and [JSON](../examples/standalone/bar.json) inputs.
