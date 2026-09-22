# Quantitative diagrams

**Supported:** `:bar`, `:line`, `:scatter`, `:treemap`, `:sankey`, `:polar`, `:radar`

Choose from the analytical question and data shape, then name the unit and domain.

| Data/question | Use | Constraint |
|---|---|---|
| Compare one signed measure across discrete categories | `:bar` | Preserve exact zero; sort only when order is not semantic. |
| Show change over elapsed dates or explicit ordinal positions | `:line` | Declare gaps; avoid many tangled series. |
| Compare two numeric variables per observation | `:scatter` | Position shows association, not causation. |
| Show nonnegative parts of one whole by area | `:treemap` | Close areas are hard to compare; use bars when precision matters. |
| Show a conserved quantity splitting and merging across three stages | `:sankey` | Every node and stage must balance; represent waste explicitly. |
| Show one nonnegative magnitude series over cyclic categories | `:polar` | Radius alone encodes value; angle and area do not. |
| Compare a few entities on the same bounded criteria | `:radar` | Every axis must share one honest scale; polygon area means nothing. |

Use a table when exact lookup is primary, and prose when one number is the conclusion. SlimGraphR intentionally omits several distribution charts; do not force unsupported data into a nearby grammar.

## Smallest useful pattern

```ruby
SlimGraphR.diagram :bar, title: 'Weekly signups', unit: 'signups' do
  scale min: 0, max: 60
  category :mon, 'Mon', 42
  category :tue, 'Tue', 57
end
```

Read `docs/bar-charts.md`, `docs/line-charts.md`, `docs/scatter-plots.md`, `docs/treemaps.md`, `docs/sankeys.md`, `docs/polar-charts.md`, and `docs/radar-charts.md`.
