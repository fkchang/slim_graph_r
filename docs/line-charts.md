# Line charts

Line charts contain 1–4 series over 3–24 required positions. A time axis accepts strictly ascending complete Gregorian `YYYY-MM-DD` dates and spaces them by elapsed days. An ordinal axis preserves unique author order, uses equal spacing, and states visibly that spacing is ordinal rather than elapsed time.

```ruby
SlimGraphR.diagram(:line, title: 'Incidents', unit: 'incidents/day') do
  x_axis :time, domain: %w[2026-01-01 2026-01-02 2026-01-11]
  series :api, 'API', focal: true do
    point 8
    gap reason: 'telemetry outage'
    point 3
  end
end
```

Every series declares one point or explicit gap at every position. A gap has no value and disconnects the line segments; it is never interpolated, bridged, or replaced by zero. Series share one linear y scale and unit. Auto constant domains use the same visible reference convention as bars. Lines are straight, without spline or area fill.

See the paired executable [Ruby](../examples/standalone/line.rb) and [JSON](../examples/standalone/line.json) inputs.
