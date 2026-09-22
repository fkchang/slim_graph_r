---
name: slim-graph-r
description: Choose and author the most honest SlimGraphR diagram for architecture, data, flow, hierarchy, strategy, or quantitative questions. Use when an agent needs to decide whether a visual helps, select among SlimGraphR's supported types, or write/render its Ruby DSL. Prefer prose or a table when they communicate the claim more directly.
license: MIT
metadata:
  short-description: Choose and author SlimGraphR diagrams
---

# SlimGraphR Diagram Chooser

Choose the picture from the reader's question, then author the smallest diagram that answers it. SlimGraphR computes layout and SVG; the author remains responsible for the facts and the claim.

## Route the request

1. **Use a diagram only when relationships, position, sequence, containment, or magnitude carry meaning.** Use prose for one conclusion, bullets for a list, and a table for direct lookup or exact row/column comparison.
2. State the reader's dominant question in one sentence. Do not start from a favorite chart type.
3. When behavior, enforcement, capacity, or risk is load-bearing, first check [semantic patterns](references/semantic-patterns.md). Then choose one family below and read only its reference. If two families are equally necessary, produce an overview and a detail rather than mixing two visual grammars.
4. Within that family, choose the narrowest supported type whose semantics match the evidence.
5. Author only declared facts. Never invent telemetry, causality, enforcement, precision, provenance, capacity, or confidence.
6. Render and inspect the real SVG. Split dense inputs or accept an actionable `LayoutError`; do not repair clarity by shrinking meaningful text.

| Dominant reader question | Read |
|---|---|
| What exists, connects, depends, deploys, or exchanges data? | [Systems](references/systems.md) |
| What is the domain/schema/class/access/storage structure? | [Data and structure](references/data.md) |
| What happens, in what order, under whose ownership, or over time? | [Flow and time](references/flow.md) |
| What contains, reports to, decomposes into, or layers above what? | [Hierarchy](references/hierarchy.md) |
| Where is the tradeoff, overlap, feedback, cause, or strategic movement? | [Strategy](references/strategy.md) |
| How much, how has it changed, how are variables related, or how does quantity flow? | [Quantitative](references/quantitative.md) |

## Authoring surfaces

Standalone Ruby:

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :architecture, title: 'Publishing path' do
  external :reader, 'Reader'
  node :app, 'Web app', emphasis: true
  flow :reader, :app
end

File.write('publishing.svg', diagram.to_svg)
```

StreamWeaver already exposes `diagram`; do not require SlimGraphR separately there. Run `streamweaver diagrams` for the complete executable atlas. The standalone CLI accepts Ruby or strict JSON:

```sh
slimgraph render diagram.rb -o diagram.svg
slimgraph render diagram.json -o diagram.html
slimgraph types
```

## Shared constraints

- One figure makes one primary claim. Use one or two focal elements at most.
- Labels and descriptions must carry meaning without relying on color.
- A qualitative coordinate is an authored judgment. A quantitative mark requires units, domain, and compatible measures.
- A diagram describes supplied information; it does not discover system truth.
- Prefer deletion. If a relationship is not part of the reader's question, omit it.
- Above the type's supported budget, split overview from detail.

## Research lineage

The question-first routing adapts ideas from [Cathryn Lavery's Diagram Design](https://github.com/cathrynlavery/diagram-design), whose current skill separates semantic behavior from visual layout. Quantitative routing also draws on [From Data to Viz](https://www.data-to-viz.com/)'s data-shape decision tree and caveats. System views follow [C4](https://c4model.com/diagrams)'s discipline of selecting an audience and abstraction level. These sources inform selection; SlimGraphR's executable examples and documented limits remain the contract.
