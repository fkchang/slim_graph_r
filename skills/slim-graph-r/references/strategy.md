# Strategy and diagnosis

**Supported:** `:quadrant`, `:venn`, `:loop`, `:fishbone`, `:wardley`

| Reader must understand | Use | Avoid when |
|---|---|---|
| Authored position against two literal qualitative axes | `:quadrant` | Scores were calculated and need quantitative comparison. |
| Named overlap among two or three sets | `:venn` | Area or population magnitude matters; equal circles encode none. |
| A reinforcing cycle whose last station feeds the first and writes to shared state | `:loop` | There is a beginning, end, or elapsed time. |
| Candidate factors grouped around one observed effect | `:fishbone` | Evidence establishes causal magnitude or priority. |
| A value chain positioned by qualitative visibility and evolution | `:wardley` | Positions are not authored strategic judgments. |

## Evidence gate

These diagrams make arguments. Label qualitative judgments as judgments. A fishbone organizes investigative leads and never proves causality. A Wardley position is not a market score. A Venn circle's area means nothing.

## Smallest useful pattern

```ruby
SlimGraphR.diagram :quadrant, title: 'Portfolio choices' do
  horizontal_axis low: 'EASY', high: 'HARD'
  vertical_axis low: 'LOW VALUE', high: 'HIGH VALUE'
  item :billing, 'Billing refresh', x: 0.72, y: 0.66, focal: true
  item :cleanup, 'Lint cleanup', x: -0.42, y: -0.46
end
```

Read `docs/quadrants.md`, `docs/venn.md`, `docs/loops.md`, `docs/fishbones.md`, and `docs/wardley-maps.md`.
