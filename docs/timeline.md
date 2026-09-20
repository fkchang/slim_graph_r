# Calendar timelines and ordered milestones

```ruby
SlimGraphR.diagram :timeline, scale: :date, style: :ruby do
  event '2026-04-01', 'Release'
  event '2026-01-01', 'First sketch'
  event '2026-01-16', 'Working renderer'
  event '2026-01-16', 'First review'
end
```

Date mode accepts complete, valid Gregorian `YYYY-MM-DD` strings. Dates sort chronologically; ties keep their original order. Dates such as `01-16`, `September`, relative words, and timestamps are not calendar dates in this API. The four-digit year and day are explicit, so output does not depend on the current year or local timezone.

Every marker is positioned using the same linear elapsed-day scale. Markers are never nudged for aesthetics. Same-day events share one marker and a callout containing all their entries. With only one date, the axis is a single date point; no interval is invented.

Callouts alternate above/below the axis. Their heights grow with text, and overlapping horizontal intervals use additional rows. Leaders avoid the callouts and tick labels. Ticks are a sparse set of actual dates, including the endpoints, and use enough spacing to remain readable. The footer states the scale. The accessible description lists events chronologically; `description:` can override it.

This is bounded layout. Calendar mode uses a 576px elapsed-day axis inside an 832px logical canvas; alternating callouts can add vertical lanes without changing horizontal date ratios. Distinct date markers less than 12px apart, or callouts that cannot be connected clearly, raise `LayoutError`. Split the timeline into overview/detail, or explicitly choose an ordered layout. Automatic axis breaks, user-specified time domains, and time-of-day axes are not implemented. A layout failure never silently substitutes an ordered list.

## Ordered mode

`scale: :ordered` preserves author order and treats date strings as captions. Both the figure and accessible description state that spacing does not measure time. Use it for `Now`, `Next`, and similar plans.

The default `scale: :auto` selects dates only if every value is a complete valid date. Otherwise it uses ordered mode, including mixed date/caption lists. Specify `:date` when invalid dates should be rejected instead of interpreted as captions.

```sh
slimgraph render timeline.json --scale date -o timeline.svg
slimgraph render timeline.rb --scale ordered -o milestones.html
```

Ruby and JSON use the same model and validation. `diagram.with(scale: :ordered)` returns a new model without changing the original. Explicit date/ordered scale choices are rejected on other diagram types.

Version 0.5.0 incorrectly imposed a minimum 48px marker gap. Version 0.5.1 corrects that defect. The reference-variant parity status remains partial.
