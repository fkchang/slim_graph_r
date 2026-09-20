# Polar charts

Polar charts show exactly one ordered nonnegative series across 4–8 categories. Categories remain in author order at equal clockwise angles. A required linear scale starts at zero, and each ray radius is exactly `R × value / max`.

```ruby
SlimGraphR.diagram(:polar, title: 'Demand by UTC window', unit: '% of peak') do
  scale min: 0, max: 100
  category :night, '00–06', 18
  category :morning, '06–12', 52
  category :midday, '12–18', 100, focal: true
  category :evening, '18–24', 0
end
```

Only rays and constant-size endpoint markers carry values. Zero retains its spoke, visible label, data attribute, and accessible description, but creates no ray or marker. Sectors, wedges, polygons, fill, donut hubs, nonzero baselines, unequal angles, sorting, negative values, multiple series, and custom geometry are rejected by the dedicated model and SVG allowlist.

The visible caption says radius is linear value and area has no meaning. Values accept exactly finite `Integer`, `Float`, or `BigDecimal`; geometry uses the original `BigDecimal`, while `precision:` controls only round-half-even labels. See the executable [Ruby](../examples/standalone/polar.rb) and [JSON](../examples/standalone/polar.json) pair.

Labels that cannot fit without overlap raise `LayoutError`; shorten them or use a table. This bounded implementation adapts the editorial direction in Cathryn Lavery's pinned Diagram Design polar reference under the vendored MIT notice. It is partial parity and does not claim a verified upstream variant.
