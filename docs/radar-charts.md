# Radar charts

Radar charts compare 2–5 entities across 3–5 ordered criteria that already share one auditable unit and required linear 0–max scale. SlimGraphR performs no hidden normalization or unit conversion.

```ruby
SlimGraphR.diagram(:radar, title: 'Backend scorecard', unit: 'score / 10') do
  scale min: 0, max: 10
  criterion :latency, 'Latency'
  criterion :recovery, 'Recovery'
  criterion :cost, 'Cost'
  entity :postgres, 'Postgres', values: { latency: 8, recovery: 9, cost: 6 }, focal: true
  entity :sqlite, 'SQLite', values: { latency: 9, recovery: 0, cost: 10 }
end
```

Every entity must provide exactly one value for every criterion in criterion order. Each vertex radius is exactly `R × value / max`; zero is the exact centre. Entity polygons are outline-only. One focal entity may use accent and visible endpoint markers; colour-independent dash patterns distinguish the others without implying rank. Polygon area is never a sum, mean, total, or other quantity, and the visible caption says so.

Negative, missing, extra, mixed-unit, native-scale, filled-polygon, and custom-geometry inputs fail. Unresolvable labels or outlines raise `LayoutError` with a comparison-table or small-multiples remedy. See the executable [Ruby](../examples/standalone/radar.rb) and [JSON](../examples/standalone/radar.json) pair.

This stricter bounded slice preserves the editorial direction in Cathryn Lavery's pinned Diagram Design radar reference and its vendored MIT attribution while rejecting that reference's filled-area treatment. It is partial parity and does not claim a verified upstream variant.
