# Diagram type parity matrix

Baseline: `dcd9317ed9ec7477b20005544f36e3313664d815`. 39 source types; 39 partial implementations, 0 missing, 0 fully verified. Named coverage is complete; full upstream variant parity is not claimed.

A shared name is not a parity claim. Verified variants remain empty until their semantic, visual, and test evidence is recorded.

The [pinned variant-gap audit](variant-gap-audit.md) separates the 117 global baseline cases from type-specific candidates. Its baseline result is 62 supported-unverified, 7 deliberate-different, 48 missing, and 0 verified. The 17 canonical named candidates are 4 supported-unverified, 2 deliberate-different, 11 missing, and 0 verified; descriptive subheadings and duplicate example filenames are not counted again.

The next release sequence is: freeze exact fixtures and semantic assertions; gate all 78 minimal-light/minimal-dark cases in a real browser; add or decide the 39 full-editorial compositions; implement the highest-value named variants; then populate `verified_variants` only after the browser, geometry, semantic, accessibility, and evidence gates pass.

| Type | Wave | Current status | Reference |
| --- | --- | --- | --- |
| Architecture | Foundation | partial | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-architecture.md) |
| Flowchart | Foundation | partial | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-flowchart.md) |
| Sequence | Foundation | partial | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-sequence.md) |
| Timeline | Foundation | partial | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-timeline.md) |
| Org Chart / Responsibility Map | Foundation | partial (bounded 0.6.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-org-chart.md) |
| State Machine | Topology and hierarchy | partial (bounded 0.7.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-state.md) |
| Dependency Graph | Topology and hierarchy | partial (bounded 0.8.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-dependency.md) |
| Deployment | Topology and hierarchy | partial (bounded 0.9.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-deployment.md) |
| IT current-state | Topology and hierarchy | partial (bounded 0.10.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-it-state.md) |
| High-Level | Topology and hierarchy | partial (bounded 0.11.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-high-level.md) |
| Tree / Hierarchy | Topology and hierarchy | partial (bounded 0.12.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-tree.md) |
| Nested Containment | Topology and hierarchy | partial (bounded 0.12.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-nested.md) |
| Layer Stack | Topology and hierarchy | partial (bounded 0.12.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-layers.md) |
| Pyramid / Funnel | Topology and hierarchy | partial (bounded 0.13.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-pyramid.md) |
| Medallion | Topology and hierarchy | partial (bounded 0.13.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-medallion.md) |
| Swimlane | Workflows and platforms | partial (bounded 0.14.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-swimlane.md) |
| Process | Workflows and platforms | partial (bounded 0.14.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-process.md) |
| Gantt Chart | Workflows and platforms | partial (bounded 0.15.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-gantt.md) |
| Kanban Board | Workflows and platforms | partial (bounded 0.15.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-kanban.md) |
| User Journey Map | Workflows and platforms | partial (bounded 0.16.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-journey.md) |
| User Story Map | Workflows and platforms | partial (bounded 0.16.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-story-map.md) |
| Data Flow | Workflows and platforms | partial (bounded 0.17.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-data-flow.md) |
| DP integration | Workflows and platforms | partial (bounded 0.18.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-dp-integration.md) |
| DP security matrix | Workflows and platforms | partial (bounded 0.19.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-dp-security-matrix.md) |
| ER / Data Model | Models and strategy | partial (bounded 0.20.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-er.md) |
| Database Schema | Models and strategy | partial (bounded 0.21.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-db-schema.md) |
| UML Class Diagram | Models and strategy | partial (bounded 0.22.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-uml-class.md) |
| Quadrant | Models and strategy | partial (bounded 0.23.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-quadrant.md) |
| Venn / Set Overlap | Models and strategy | partial (bounded 0.24.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-venn.md) |
| Loop | Models and strategy | partial (bounded 0.25.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-loop.md) |
| Fishbone / Ishikawa | Models and strategy | partial (bounded 0.26.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-fishbone.md) |
| Wardley Map | Models and strategy | partial (bounded 0.27.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-wardley.md) |
| Bar / Column Chart | Quantitative charts | partial (bounded 0.28.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-bar.md) |
| Line Chart | Quantitative charts | partial (bounded 0.28.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-line.md) |
| Scatter Plot | Quantitative charts | partial (bounded 0.28.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-scatter.md) |
| Radar / Spider | Quantitative charts | partial (bounded 0.30.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-radar.md) |
| Polar Chart | Quantitative charts | partial (bounded 0.30.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-polar.md) |
| Treemap | Quantitative charts | partial (bounded 0.29.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-treemap.md) |
| Sankey / Flow-Quantity | Quantitative charts | partial (bounded 0.29.0 slice) | [Type contract](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-sankey.md) |

## 0.3.0 progress

Flowcharts now have real terminators/diamonds/junctions and guarded-exit validation. Shared graph routing separates parallel strokes and reserves space for labels and crossing hops. Evidence lives in spec/flowchart_spec.rb and the rendered flowchart example. Status remains partial: full editorial framing, legends, type-specific reference variants and the other documented gaps still need verification.

## 0.4.0 progress

Sequence diagrams now preserve activations, alt/opt/loop frames, typed messages, and guarded regions in Ruby, JSON, accessible descriptions and exports. Scope and geometry regressions are covered in spec/sequence_spec.rb. The type remains partial pending the full reference-variant audit and editorial presentation.


## 0.5.0 progress

0.5.0 introduced date-scaled history and ordered milestones, but its minimum marker gap distorted some intervals. Treat its elapsed-spacing claim as superseded by 0.5.1.

## 0.5.1 correction

Calendar markers now retain exact elapsed-day positions after stable chronological sorting. Same-day events share a marker, text uses measured callouts and separate rows, ticks remain readable, and indistinguishable dates cause an explicit error. Strict Gregorian parsing removes implicit-year guesses. Status remains partial: broken-axis density handling and the full reference-variant audit are not complete.

## 0.6.0 org-chart slice

Org charts now have ownership semantics (`owner`/`invoke`/`scope`), explicit unavailable-owner treatment, strict Ruby/JSON parity, and escalation/approval rules in a separate footer strip. The bounded slice validates one parent per child, rejects cycles, supports disconnected roots and forests, and enforces 12 visible nodes, four tiers (root is tier 1), five direct reports per parent, one emphasized node, and two combined rule callouts. Generated descriptions retain names, invocation routes, scopes, unavailable state, reporting edges, and both rule types.

Status remains **partial**. Connectors are independently routed; a shared sibling bus is not guaranteed. Existing `kind` palette treatments remain in use instead of a new org-only role taxonomy. Summary cards and legends are outside this slice, so this is bounded parity rather than full upstream parity.

## 0.7.0 state-machine slice

State machines now have a dedicated lifecycle model with immutable states and transitions, strict Ruby/JSON parity, one initial marker, one or two finals, event/guard/action labels, self-loops, one bounded simple cycle, and reachability validation. Right and down layouts use rounded states, entry/final markers, curved routes, and accessible descriptions. Dense route or label placement can raise `LayoutError`; crossing-free rendering is not a blanket guarantee for every topology. Composite/history states, forks, anonymous transitions, nested/overlapping cycles, and “from any state” arrows remain outside the bounded slice. Status remains **partial** against the pinned upstream reference.

## 0.8.0 dependency slice

Dependency graphs now have dedicated dependent→requirement semantics, strict Ruby/JSON parity, ranked down layout, external version/registry metadata, computed fan-in badges on every node, and one validated real cycle routed through an outside accent lane. The bounded slice allows 9 nodes, 14 edges, four ranks, one cycle, and two accent elements; one-parent branching data uses `:tree` with nested `root`/`child` blocks. Ordinary paths cannot double back upward and congested routes may raise `LayoutError`. Status remains **partial** against the pinned upstream reference.

## 0.11.0 high-level slice

High-level diagrams now have a dedicated source/component phase model, strict Ruby/JSON parity, bounded horizontal geometry, one explicit focal component, orchestration targets, automatic concern pairing, and source-type accessible semantics. The bounded slice allows 3–5 phases, 1–4 first-phase sources, 1–2 later components per phase, 8 components, 12 forward links, one orchestration bar, two crosscuts, and exactly one focal. Same-phase/backward/query links and authored edge labels are excluded. Status remains **partial** against the pinned upstream reference.

## 0.12.0 hierarchy-family slice

Tree / Hierarchy, Nested Containment, and Layer Stack now have dedicated immutable models, strict Ruby/JSON parity, CLI and optional StreamWeaver forms, accessible descriptions, and type-specific layouts. Tree supports one root with direct child buses, depth 1–4, five nodes per tier, five children per parent, and zero or one focal node. Nested containment supports one fixed-down chain of 3–5 scopes with regular insets and automatic innermost focus. Layer Stack supports 4–6 equal bands, one focal layer, an `Abstraction` axis by default, up/down indicators, and contiguous numeric or unique semantic indices. These are partial bounded slices; no verified variants or complete upstream parity are claimed.

## 0.13.0 pyramid-medallion slice

Pyramid / Funnel and Medallion now have dedicated immutable models, strict Ruby/JSON parity, CLI and optional StreamWeaver forms, accessible descriptions, and type-specific layouts. Pyramid hierarchy remains ordinal while measured mode preserves exact proportional widths, equal-count plateaus, zero tails, and outside labels for narrow bands. Medallion supports 3–6 tiers, one focal tier, an optional final archive, adjacent cubic promotions, semantic concern colors, and 0–2 write paths. These are partial bounded slices; no verified variants or complete upstream parity are claimed.

## 0.14.0 workflow family slice

Swimlane and Process now have dedicated immutable models, strict Ruby/JSON parity, horizontal actor-lane layouts, CLI and optional StreamWeaver forms, accessible descriptions, and faithful-layout errors. Swimlane supports 1–6 lanes, 1–12 stages, one activity per cell, 24 activities, and 24 handoffs with one optional focal handoff. Process adds unique 1–3 character lane keys, tools in cards/descriptions, payload codes with unknown boundary handling, exactly one focal stage and operation, 24 ordinary handoffs, and one optional neutral dashed return trigger. These remain partial bounded slices with no verified variants or complete upstream parity claimed.

## 0.15.0 planning-board slice

Gantt and Kanban now have dedicated immutable models, strict Ruby/JSON parity,
checkout CLI and library forms, accessible descriptions, and faithful-layout
errors. Gantt preserves exact elapsed-day positions for complete Gregorian
dates, uses half-open `[start, finish)` task bars, retains phase/task
declaration order, and supports exact milestone points plus static markers.
Kanban preserves column/card order, derives honest counts, renders supplied
WIP limits and violations, and retains every supplied card state and optional
ticket/owner metadata. Gantt allows 0–4 phases, 0–12 tasks, up to 8
milestones, 0–2 markers, and one focal task. Kanban allows 2–5 columns, 0–4
cards per column, 0–12 cards total, and one focal card. Both remain bounded
partial slices with no verified variants or complete upstream parity claimed;
see [gantt.md](../gantt.md) and [kanban.md](../kanban.md).

## 0.16.0 journey/story-map slice

User Journey and User Story Map now have dedicated immutable models, strict
Ruby/JSON parity, checkout CLI and library forms, optional StreamWeaver
integration, accessible descriptions, and faithful-layout errors. User
Journey keeps one persona, declaration-ordered stages, explicit ordinal
sentiments, a unique lowest trough, optional touchpoints, and trough-only pain
markers. User Story Map keeps one persona, ordered activities and steps,
release bands, one non-final cut, authored estimate/ticket metadata, and at
most one risk story. Both remain bounded partial slices with no verified
variants or complete upstream parity claimed; see [journeys.md](../journeys.md)
and [story-maps.md](../story-maps.md).

## 0.17.0 data-flow slice

Data Flow now has a dedicated immutable role/stage/transfer/handoff model,
strict Ruby/JSON parity, checkout CLI and library forms, optional StreamWeaver
integration, accessible descriptions, and faithful-layout errors. The bounded
slice uses 2–4 roles, 2–6 ordered steps, 2–16 transfers, and up to 20
handoffs. Transfers occupy one role/stage cell, declare tools and optional
payloads, and handoffs use only ordinary, trigger, focal, or publish kinds.
Exactly one linked focal step, transfer, and handoff claim is required. This
remains a partial slice with no verified variants; see [data-flows.md](../data-flows.md).

## 0.18.0 DP-integration slice

DP integration now has a dedicated immutable platform-zone model with strict
Ruby/JSON parity, explicit source, consumer, layer-service, and wire semantics,
checkout CLI and library forms, optional StreamWeaver integration, accessible
descriptions, and faithful-layout errors. The bounded scene uses one platform
zone with ordered bars and one row, measured 160×64px side cards, distinct
boundary ports, neutral ordinary wires, at least 8px protocol-label clearance,
and one footer-card strip. It allows 0–6 sources and consumers, 2–6 platform
components, 0–3 layer services, and 20 wires, with exactly two focal and one
serving component. This remains partial with no verified variants; see
[platform-integrations.md](../platform-integrations.md).

## 0.19.0 DP-security-matrix slice

DP security matrix now has dedicated immutable role, component, and permission
records with strict Ruby/JSON parity, checkout CLI and library forms, optional
StreamWeaver integration, generated accessibility text, and faithful-layout
errors. Every component × role coordinate is explicit; `unknown`, denial, and
invalid omission remain distinct. The connector-free measured table supports
2–5 roles, 2–10 components, 4–36 cells, and zero or one focal permission, with
optional role codes, component hints, and a focal-only note. This remains
partial with no verified variants; see [access-matrices.md](../access-matrices.md).

## 0.20.0 ER slice

ER now has dedicated immutable entity, field, and relationship records with
strict Ruby/JSON parity, checkout CLI and library forms, optional StreamWeaver
integration, generated accessibility text, and faithful-layout errors. The
bounded renderer preserves natural card heights, explicit key classifications,
neutral orthogonal relationships, distinct ports, and exact authored
cardinality at both endpoints. It accepts 2–6 entities, 1–6 fields per entity,
1–8 relationships, and zero or one focal entity. No relationship, physical
foreign key, SQL type, or deletion behavior is inferred. This remains partial
with no verified variants; see [entity-relationships.md](../entity-relationships.md).

## 0.21.0 database-schema slice

Database schema now has dedicated immutable table, column, and foreign-key
records with strict Ruby/JSON parity, checkout CLI and library forms, optional
StreamWeaver integration, generated accessibility text, and faithful-layout
errors. The bounded renderer preserves literal SQL types, constraint chips,
named indexes, explicit schema groups, 24px rows, exact row endpoints,
symmetric shared-row ports, masked action labels, and every authored cascade.
Cascade treatment applies to the dependent source-table header; referenced
parents and other actions stay neutral. It accepts 2–5 tables, 1–8 columns and
0–3 indexes per table, and 1–6 foreign keys. Nothing is inferred. This remains
partial with no verified variants; see [database-schemas.md](../database-schemas.md).

## 0.22.0 UML-class slice

UML class diagrams now have dedicated immutable class and relation records,
strict Ruby/JSON parity, checkout CLI and library forms, optional StreamWeaver
integration, generated accessibility text, and faithful-layout errors. Natural
compartments preserve literal members. Six explicit relation kinds preserve
target triangles, declared-owner diamonds, plain association lines with exact
endpoint multiplicities, and dependency-only open arrows. The logical 8px
grammar role renders at 1.5× for a 12px physical minimum. This remains partial
with no verified variants; see [uml-classes.md](../uml-classes.md).

## 0.23.0 quadrant slice

Quadrants now have dedicated immutable axis and item records, strict Ruby/JSON
parity, checkout CLI and library forms, optional StreamWeaver integration,
generated accessibility text, and faithful-layout errors. Literal low/high
endpoint phrases surround a measured 720×480 plot. Finite authored x/y values
map exactly within `[-1,1]`, outside the central safety band, without scoring,
snapping, jitter, or collision movement. Labels remain in their authored
quadrant and the fixed caption states the qualitative-position limit. The
logical 8px axis role renders at 1.5× for a 12px physical minimum. This remains
partial with no verified variants; see [quadrants.md](../quadrants.md).

## 0.24.0 Venn slice

Venn diagrams now use dedicated immutable set and intersection records with strict Ruby/JSON parity, checkout CLI and library forms, optional StreamWeaver integration, generated accessibility text, and faithful-layout errors. Exactly two sets require their sole pair; exactly three sets require every pair and the triple. Fixed equal circles encode named topology only, never area, population, counts, or weights. External set labels and fixed pair/triple regions are measured, and one optional author-selected focal overlap receives a clipped accent tint. This remains partial with no verified variants; see [venn.md](../venn.md).

## 0.25.0 Loop slice

Loop diagrams now use dedicated immutable hub, station, cycle, and write-back records with strict Ruby/JSON parity, checkout CLI and library forms, optional StreamWeaver integration, generated accessibility text, and faithful-layout errors. One required clockwise cycle preserves authored ring order and explicitly declares adjacency plus closure. Every one of five to eight stations has exactly one explicit write-back to the single shared-state hub. Same-radius arcs and edge-clipped dashed spokes preserve the topology without inferred paths. This remains partial with no verified variants; see [loops.md](../loops.md).

## 0.26.0 Fishbone slice

Fishbone diagrams now use dedicated immutable effect and category records with atomic factor scopes, strict Ruby/JSON parity, checkout CLI and library forms, optional StreamWeaver integration, generated accessibility text, and faithful-layout errors. One observed effect receives 2–5 author-ordered categories across explicit upper and lower slots, with 1–3 literal factors each. The measured spine, 200px effect head, exact 60-degree bones, 32px factor ticks, and coordinated third-lower expansion preserve the bounded geometry. Categories and factors remain neutral investigated leads and never claim causation. This remains partial with no verified variants; see [fishbones.md](../fishbones.md).

## 0.27.0 Wardley slice

Wardley maps now use dedicated immutable component and dependency records with strict Ruby/JSON parity, checkout CLI and library forms, optional StreamWeaver integration, generated accessibility text, and faithful-layout errors. Two to nine components retain explicit qualitative evolution bands and linear authored visibility, while one to twelve straight links state value-chain dependence without runtime meaning. Up to two strictly adjacent rightward movements receive dashed accent arrows. The 960px plot keeps all meaningful text at a 12px logical floor and produces a 1280px readable SVG. Positions never move to repair interference. This remains partial with no verified variants; see [wardley-maps.md](../wardley-maps.md).

## 0.28.0 Cartesian quantitative slice

Bar, line, and scatter now share immutable BigDecimal values, strict Ruby numeric and JSON contracts, half-even plain formatting, finite linear domains, visible scale metadata, measured labels, and unsafe Float-mapping failures. Bars preserve signed lengths from exact zero and paint no zero rectangle. Lines distinguish elapsed-day time from equal ordinal spacing and disconnect at explicit gaps. Scatter requires both explicit scales and units and uses position alone. All three remain partial with no verified variants; see [bar-charts.md](../bar-charts.md), [line-charts.md](../line-charts.md), and [scatter-plots.md](../scatter-plots.md).

## 0.29.0 area and conservation slice

Treemap and Sankey extend the immutable BigDecimal foundation with strict type-specific Ruby and JSON contracts. Treemap partitions one rectangle into exact positive area shares, retains zeros without cells, and moves tiny-cell copy to an external keyed legend. Sankey enforces exact three-stage conservation and uses one unsnapped scale for every node and ribbon with disjoint horizontal attachment intervals. Both remain partial with no verified variants; see [treemaps.md](../treemaps.md) and [sankeys.md](../sankeys.md).

## 0.30.0 radial quantitative slice

Polar and Radar complete named type coverage with dedicated immutable BigDecimal models, strict JSON, measured radial geometry, visible non-area captions, standalone and optional StreamWeaver examples, and faithful-layout errors. Polar preserves equal authored angles and exact value rays while omitting zero rays and markers. Radar accepts one already-common scale, draws outline-only polygons, and distinguishes entities with stroke patterns. Both are bounded partial slices; full upstream variant parity and verified variants remain unclaimed. See [polar-charts.md](../polar-charts.md) and [radar-charts.md](../radar-charts.md).
