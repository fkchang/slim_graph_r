# SlimGraphR + StreamWeaver — proposed build

Status: approved and implemented as SlimGraphR 0.1.0. See README.md for the shipped API and explicit limitations. RSpec replaces the originally proposed test/ directory at the user's request.

## Outcome
Write a short Ruby description of a diagram and get an editorial SVG: clear hierarchy, restrained orange emphasis, legible labels, and deliberate connector routing. Use the same output in StreamWeaver apps, live canvas, saved documents, and exported HTML.

## Package boundary
Build `slim_graph_r` here as an independently usable Ruby gem. It owns the semantic model, theme tokens, text measurement, layout, routing, and SVG serialization. StreamWeaver receives an additive `diagram` component that delegates rendering to the gem. Existing Mermaid calls continue to work; unsupported types receive a clear error and guidance to use Mermaid, rather than a lossy automatic translation.

Authoring interface:

```ruby
diagram :architecture, title: "From intent to interface" do
  node :intent, "Describe the system", detail: "Ruby DSL"
  node :layout, "Compute the layout", emphasis: true
  node :svg, "Render the diagram", detail: "SVG"
  edge :intent, :layout
  edge :layout, :svg
end
```

## Delivery slices
1. Architecture and flowchart proof: shared node/edge model; explicit groups and orientation; branches, merges, labeled edges, and cycle handling. Establish supported graph limits explicitly. Ship a gallery with real branching diagrams, not only chains.
2. StreamWeaver integration: DisplayDSL method, component, appropriate render adapters, dependency loading, canvas reader and export support. Namespace SVG IDs so several diagrams coexist. Render escaped content with accessible titles/descriptions and theme support.
3. Sequence and timeline: distinct layout strategies sharing typography and rendering primitives. Add org charts once hierarchical layout is proven.
4. Benchmark and authoring guide: equivalent diagram content in Ruby DSL, Mermaid, and hand-authored SVG; report authoring size and measured token counts using a named tokenizer, plus rendering timing. No savings claims before measurement.

## Design direction
Use diagram-design's current semantic tokens and editorial type hierarchy as the reference. Adapt its layout grammar into deterministic code. Pin the upstream revision and retain applicable MIT attribution for copied material. The accent identifies one or two focal elements; it does not decorate every node. Provide offline font fallbacks and test their label fit.

The renderer must budget text width and wrap labels, reserve connector corridors, and account for edge labels. A general graph-layout engine is substantial work; first release support should be bounded and visibly documented. Dense graphs must produce an actionable limit/error if they cannot be laid out faithfully.

## Proposed files
- `lib/slim_graph_r.rb`, `lib/slim_graph_r/diagram.rb`: public interface and validated semantic model.
- `lib/slim_graph_r/theme.rb`, `lib/slim_graph_r/text.rb`: design tokens and label sizing.
- `lib/slim_graph_r/layout/`, `lib/slim_graph_r/svg.rb`: type-specific layout, shared routing, and escaped SVG output.
- `spec/`, `examples/`, `docs/for_llms.md`: meaningful geometry tests, reviewable gallery, and short authoring reference.
- StreamWeaver `lib/stream_weaver/display_dsl.rb`, new diagram component, render adapters and corresponding tests/docs: integration, subject to the reviewed Tyrion story flow.

## Acceptance evidence
- Branch/merge/cycle, disconnected nodes, long labels, Unicode, repeated edges, invalid references, and escaped markup fixtures.
- Geometry assertions for overlapping nodes and connectors crossing unrelated boxes within supported cases.
- Multiple diagrams in one document without SVG ID collisions.
- Visual review at desktop and narrow widths, light and dark themes.
- Same diagram available in live canvas, saved-document reader, and standalone export, without a rendering network request.
- StreamWeaver relevant regression suite and its required story gates.

## Integration decision
The registry identifies StreamWeaver at `~/work/rstreamlit/stream_weaver`. DisplayDSL already exposes Mermaid as a component, which provides a suitable additive integration pattern. Its checkout contains unrelated work. The integration is supplied entirely by this gem via its public component interface. No StreamWeaver source or Tyrion state was changed. A future built-in integration can follow StreamWeaver's reviewed story process.

## References
- User's research summary and its linked full report, dated 2026-09-08.
- https://github.com/cathrynlavery/diagram-design
- https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/skills/diagram-design/references/style-guide.md
