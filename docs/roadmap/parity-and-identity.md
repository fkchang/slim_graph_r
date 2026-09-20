# Full diagram parity and a Ruby identity

Status: all thirty-nine named types have partial implementations, with 39 partial, 0 missing, and 0 verified. Polar and radar are the bounded 0.30.0 radial slice. Named coverage is complete; no type is fully verified and full upstream variant parity is not claimed.

The [pinned variant-gap audit](variant-gap-audit.md) is the current source of truth for presentation and named-variant readiness. Across the 117 global minimal-light/minimal-dark/full-editorial cases it records 79 supported-unverified, 7 deliberate-different, 31 missing, and 0 verified. Separately, 17 canonical named candidates reconcile to 4 supported-unverified, 2 deliberate-different, 11 missing, and 0 verified. Ambiguous headings and duplicate example names remain audit evidence rather than extra contract variants.

Work proceeds through an exact-fixture gate, all 78 minimal light/dark browser and semantic checks, the 39 full-editorial composition decisions, then the highest-value named variants: High-Level vertical concerns, Funnel, Medallion style mapping, grouped/stacked/dumbbell bars, slopegraph/bump, and bubble/beeswarm. `verified_variants` stays empty until each exact case passes geometry, browser, semantic, accessibility, and evidence review.

## Target and attribution

Full variant parity remains the target after completing all thirty-nine diagram names. Pin verification to diagram-design revision `dcd9317ed9ec7477b20005544f36e3313664d815`, where the source contains 39 `type-*.md` references. Upstream repository metadata says 38 in one place, while its README and this source inventory say 39; use the actual inventory as the baseline.

Parity has two parts:

1. **Renderer parity:** semantic content, layout grammar, type-specific relationships, label/connector rules, visual variants, accessibility, output sizes, and numeric fidelity.
2. **Workflow parity:** semantic pattern selection, annotations, import fidelity, brand profiles, output/export controls, and optional accessible motion. This may live in CLI/agent integrations rather than the core gem, but remains on the parity roadmap.

Ruby adds an independently usable renderer, elegant DSL, reproducibility, testable geometry, and measured authoring economy. We should give visible credit to Cathryn Lavery's Diagram Design in the README and gallery and retain the MIT notice for adapted materials. Changes to visual style do not erase that lineage. This project is an independent Ruby implementation; do not describe it as an official port or claim parity before verification.

## Audit the original five first

| Current type | Verified gap against upstream reference |
| --- | --- |
| Architecture | 0.3.0 separates parallel graph paths, adds ordinary crossing hops, and keeps label masks 8px off connector centerlines. Complete node treatments, legends, full editorial framing, and broader conformance cases remain. |
| Flowchart | 0.3.0 adds real decision diamonds, start/finish shapes, merge dots, guarded exits, and conventional simple Yes/No placement. Full editorial variants, legends, and complete upstream visual comparison remain. |
| Sequence | 0.4.0 adds scoped/nested activations, alt/opt/loop frames, distinct call/return/async/success markers, and Ruby/JSON control structure. Full editorial framing, broader reference-variant checks and any remaining intentional deviations still need verification. |
| Timeline | 0.5.1 corrects 0.5.0's marker nudging and date guessing. Exact chronological positions, same-day groups, dynamic callouts, clear ticks and dense-input errors now have regression evidence. Full editorial variants and broken-axis density handling remain. |
| Org chart | 0.6.0 adds separate invocation and responsibility fields, escalation/approval callouts, unavailable-owner treatment, strict Ruby/JSON parity, and type-specific complexity limits. Full upstream parity remains open. |
| State machine | 0.7.0 adds a dedicated bounded lifecycle model, strict Ruby/JSON parity, entry/final markers, event/guard/action labels, self-loops, one simple cycle, reachability validation, and curved right/down routes. Dense scenes can fail with `LayoutError`; full upstream parity remains open. |
| Dependency graph | 0.8.0 adds a dedicated ranked dependency model, dependent→requirement arrows, strict Ruby/JSON parity, external version/registry metadata, fan-in badges, one validated real cycle, and faithful-layout errors. One-parent branching input can use the available `:tree` renderer with nested `root`/`child` blocks; full upstream parity remains open. |
| Deployment | 0.9.0 adds three-level zone/infrastructure/artifact containment, typed placement, replicas, versioned chips, protocol/port paths, strict Ruby/JSON parity, and faithful-layout errors; full upstream parity remains open. |
| IT current-state | 0.10.0 adds horizontal phase/system containment, external and pain-point states, labelled handoffs with backward/dashed validation, crosscut footer services, strict Ruby/JSON parity, and faithful-layout errors; full upstream parity remains open. |
| High-Level | 0.11.0 adds a dedicated bounded data-stack model with source and component phases, forward data links, one explicit focal, orchestration targets, concern-paired crosscuts, strict Ruby/JSON parity, and faithful-layout errors; full upstream parity remains open. |
| Tree / Hierarchy | 0.12.0 adds one-root nested `root`/`child` trees, orthogonal sibling buses, optional focal treatment, strict Ruby/JSON parity, and bounded depth/breadth; full upstream parity remains open. |
| Nested Containment | 0.12.0 adds one fixed-down 3–5 scope chain, regular insets, masked labels, automatic innermost focus, and strict Ruby/JSON parity; full upstream parity remains open. |
| Layer Stack | 0.12.0 adds 4–6 equal bands, required indices, one focal layer, axis/indicator metadata, strict Ruby/JSON parity, and contiguous numeric-index validation; full upstream parity remains open. |
| Pyramid / Funnel | 0.13.0 adds separate ordinal hierarchy and quantity-faithful measured modes, pyramid/funnel orientation validation, plateau/zero-tail preservation, outside leaders for narrow bands, strict Ruby/JSON parity, and faithful-layout errors; full upstream parity remains open. |
| Medallion | 0.13.0 adds fixed 3–6 tier cards, one focal tier, optional final archive, adjacent cubic promotions, semantic concern styling, 0–2 measured write paths, strict Ruby/JSON parity, and faithful-layout errors; full upstream parity remains open. |
| Swimlane | 0.14.0 adds dedicated actor lanes, contiguous numbered stages, one activity per cell, 24-card/handoff bounds, strict Ruby/JSON parity, optional focal handoff, and faithful-layout errors; full upstream parity remains open. |
| Process | 0.14.0 adds keyed actor lanes, tool and payload cards, independent focal stage/operation slots, 24 ordinary handoffs, one optional neutral dashed return trigger, strict Ruby/JSON parity, and faithful-layout errors; full upstream parity remains open. |
| Gantt Chart | 0.15.0 adds an exact elapsed-day calendar plan with half-open task bars, declaration-order phase rows, exact milestone points, static markers, strict Ruby/JSON parity, and faithful-layout errors; full upstream parity remains open. |
| Kanban Board | 0.15.0 adds an ordered work-state census with columns, cards, optional metadata, neutral/blocked/waiting/done states, honest WIP limits, strict Ruby/JSON parity, and faithful-layout errors; full upstream parity remains open. |

These are parity requirements, not regressions against the documented v0.1 scope. A new type should not be implemented by aliasing the generic graph renderer when its defining meaning is different.

## 0.10.0 IT current-state parity boundary

IT current-state diagrams document a modernization “before” picture. Horizontal phases contain named systems with optional technical details and `standard`, `external`, or `pain_point` state. Labelled handoffs use `neutral`, `link`, or `accent` style plus an independent `dashed` boolean for a dashed line. A pain-point endpoint makes touching handoffs accent. Source order controls forward/backward permission; backward handoffs require an external endpoint and `dashed: true`. Crosscut services are footer bars with no graph endpoints, and the automatic legend reports only semantics used by the diagram.

The bounded slice supports 2–4 phases, 1–5 systems per phase, 16 systems, 24 handoffs, two pain points, and three crosscuts. Phase labels are uppercase and at most 14 characters; handoff labels are uppercase and at most 8. Vertical layouts, icons, custom colors, side overrides, caller-authored legends, and full editorial framing remain outside the slice. Invalid structure and routes or labels that cannot be placed faithfully fail explicitly. See the [IT current-state authoring guide](../it-current-state.md).

## 0.9.0 deployment parity boundary

Deployment diagrams use zones as environment or network boundaries. Each zone contains typed infrastructure (`host`, `vm`, `pod`, `managed`, or `cdn`), and each infrastructure node contains one or more versioned artifacts. Positive `replicas:` values remain a badge on one node. Network paths require a protocol and port; internal paths are muted, cross-zone paths use the style's link role, and `async: true` is dashed.

The bounded layout measures declaration-order zone columns, reserves a 40px zone header, stacks nodes inside their authored zone, measures artifact name/version pairs, and keeps type tags, replica badges, chips, labels, and paths in the same containment grammar. Budgets are 3 zones, 6 infrastructure nodes, 9 artifact chips, 8 paths, and two combined emphasized nodes/paths. Invalid structure and routes or labels that cannot be placed faithfully fail explicitly. This is partial parity against the pinned reference, not a full upstream parity claim.

See the [deployment authoring guide](../deployments.md) for the strict Ruby/JSON contract and CLI forms.

## 0.11.0 high-level parity boundary

High-level diagrams document a compact end-to-end data stack. The first horizontal phase contains external sources, later phases contain 1–2 components, and `connect` creates unlabeled forward interphase data links. One explicitly focal component receives the semantic accent. An optional orchestration bar targets components and defaults to concern `Orchestration`; bar-originating trigger semantics take precedence when the target is focal. Crosscuts have required distinct concerns and pair automatically with vertical chevrons. `cluster` is an optional label defaulting to `Cluster`. Source types (`db`, `ftp`, `web`, `legacy`, `api`) remain accessible semantics while source icons are deferred.

The bounded model supports 3–5 phases, at most five columns, 1–4 sources, 1–2 components per later phase, 8 components, 12 links, three outgoing links per source/component, one orchestration bar, two crosscuts, and exactly one explicit focal. Orchestration targets must be the top component in their phases. Same-phase, backward, query, authored-label, manually vertical, unclustered, icon, custom-color, side-override, and editorial-card variants remain outside the slice. Invalid structure or unplaceable geometry raises `LayoutError`. This is partial parity against the pinned reference; see [high-level.md](../high-level.md).

## 0.13.0 pyramid and medallion parity boundary

Pyramid/Funnel diagrams separate ordinal hierarchy from measured quantity. Both
Ruby and JSON default to `orientation: :pyramid` and `mode: :hierarchy`.
Hierarchy accepts four to six levels and uses a linear taper without claiming
amounts. Measured mode accepts either orientation, requires a shared unit and
exact chained finite nonnegative boundaries, preserves equal-count plateaus and
zero tails, and computes every face width from `480 * amount / first.from`.
Narrow labels move to collision-free outside leaders; no readability floor may
alter the encoded width. One focal level is optional but cannot be the base.

Medallion diagrams use 3–6 left-to-right fixed cards, exactly one focal tier,
an optional final archive, one promotion for every adjacent pair, at most two
semantic concerns, and zero to two write paths. Concern colors follow the
curated semantic palette. Incoming focal styling wins over archive treatment,
which wins over a target concern match; write-path tags, titles, and details
use measured distinct lanes. Non-adjacent/backward/bidirectional promotions,
arbitrary colors, and arbitrary coordinates remain outside the slice. See the
[pyramid guide](../pyramids.md) and [medallion guide](../medallions.md).

## 0.6.0 org-chart parity boundary

The org-chart implementation is a bounded partial-parity slice. Ruby supports `owner` alongside compatible generic `node` calls; both preserve `detail` and render name, invocation, scope, and unavailable state as separate semantic text roles. JSON uses the same model with strict node fields and top-level `escalations`/`approvals`. Reporting edges remain orthogonal graph connectors, while rules render after a divider in a blocked footer strip and remain out of the hierarchy. Generated SVG descriptions include ownership fields, unavailable state, edges, and rules.

Validation permits forests and requires at most one incoming reporting edge per child; cycles, unknown rule references, and over-budget charts fail with actionable errors. The org budgets are 12 visible nodes, four tiers (root is tier 1), five direct reports per parent, one emphasized node, and two combined escalation/approval callouts.

This is not full upstream parity. Connectors are routed independently, so a shared sibling bus is not guaranteed. Existing `kind` palette treatments are reused rather than adding a new org-only taxonomy. Summary cards and legends remain outside the slice. See the [org-chart authoring guide](../org-charts.md) and executable [Ruby](../../examples/standalone/org_ownership.rb)/[JSON](../../examples/standalone/org_ownership.json) examples.

## 0.14.0 workflow family parity boundary

Swimlane and Process use fixed horizontal actor-lane grids: a 140px actor
column, 112px stage columns, 80px lanes, and measured 100×64px cards. Stages
number contiguously; empty cells mean no work and remain in descriptions.
Swimlane has one optional focal handoff. Process requires unique 1–3 character
lane keys, exactly one focal stage and operation, payload codes `LS`, `DB`,
`TB`, `FL`, or `WB`, and 24 ordinary handoffs plus one optional labelled
neutral dashed trigger. Tools remain in cards and descriptions; the legend
reports numbered/focal steps, used payloads, and effective flows. Boundary
payloads are rejected when supplied rather than dropped. Conversions, parallel
gateways, custom colors, vertical lanes, and arbitrary coordinates remain
outside this partial slice. See the [swimlane guide](../swimlanes.md) and
[process guide](../processes.md).

## 0.15.0 planning-board parity boundary

Gantt uses 0–4 non-nested phases with 0–12 declaration-ordered tasks, complete
Gregorian all-day dates, exact half-open `[start, finish)` bars, 0–8 point
milestones, and 0–2 static markers. Its 180px label column, 760px elapsed-day
timeline, exact 24px bars, year-aware ticks, phase/global tracks, and
finish-exclusive caption preserve calendar meaning; under-one-pixel bars,
overlapping same-track milestone diamonds, or unplaceable measured text raise
faithful-layout errors. Kanban uses 2–5 declaration-ordered columns, 0–4 cards
per column, 0–12 cards total, optional positive WIP limits, optional
ticket/owner metadata, four explicit states, and one optional focal card.
Counts derive from displayed cards, over-limit counts remain honest, and no
connectors, sorting, inferred state, aggregation, or silent WIP repair is
allowed. Both are bounded partial slices with no verified variants; see the
[Gantt guide](../gantt.md) and [Kanban guide](../kanban.md).

## 0.16.0 journey/story-map parity boundary

User Journey and User Story Map use dedicated models for two different static
Read surfaces. A journey names one person or role, preserves 2–6 ordered stages,
and records one explicit ordinal sentiment per stage, one unique lowest trough,
optional touchpoints, and at most two trough-only pains. Its tracked row-label
margin is measured with a 64px minimum (84px for the current `TOUCHPOINTS` and
level labels), followed by 200px stage columns, 24px gutters, and 4px right
plot padding; the data curve communicates sequence and never a continuous
score. A story map names one person or role, preserves 2–5 ordered activities
with 1–2 steps each, and 2–3 release bands containing authored story cards.
Exactly one non-final release has a cut; estimates and tickets remain literal
metadata and at most one story is risk-marked. Its 96px release-label margin,
200px activity columns, 24px gutters, and 16px right stroke padding retain
measured cards and gap guides. Both reject inferred state, sentiment,
priority, calendar, or external-ticket meaning, raise `LayoutError` when a
faithful bounded layout cannot fit, and replace generated descriptions exactly
when an author supplies `description:`. See the [journey guide](../journeys.md)
and [story-map guide](../story-maps.md).

## 0.17.0 data-flow parity boundary

Data Flow uses a dedicated horizontal role × stage grid. Roles require unique
one-to-three-character uppercase keys; ordered steps receive contiguous
ordinals; and each transfer occupies one declared role/stage cell, requires a
tool, and retains optional input/output payloads from the closed `web`,
`dataset`, `table`, `file`, and `stream` vocabulary. Handoffs are limited to
ordinary, trigger, focal, and publish kinds: ordinary/publish handoffs advance
to a later step, triggers are unlabelled same-step downward role handoffs, and
the focal handoff crosses roles and targets the focal transfer in the focal
step. Exactly one linked focal claim is required.

The fixed scene uses a measured role column, 168px step slots, 36px headers,
88px role bands, 152×72px transfer cards, distinct ports, orthogonal routes,
and an 8px masked focal-label gap. Budgets are 2–4 roles, 2–6 steps, 2–16
transfers, and 20 handoffs. Payload conversion, lineage, arbitrary labels on
non-focal handoffs, arbitrary colors/icons/coordinates, and inferred routes
remain outside the bounded slice. Invalid content or unplaceable text/routes
raises `LayoutError`; an author `description:` replaces generated prose
exactly. Status remains partial with no verified variants; see the [data-flow
guide](../data-flows.md).

## 0.18.0 DP-integration parity boundary

DP integration uses one bounded platform zone with ordered bars and one row,
declared sources, consumers, layer-wide services, and explicit ordinary,
federated, trigger, and serve wires. The measured scene preserves side-card,
protocol, boundary-port, and one-strip footer geometry. Exactly two platform
components are focal and exactly one serves consumers. Status remains partial
with no verified variants; see the [platform-integration guide](../platform-integrations.md).

## 0.19.0 DP-security-matrix parity boundary

DP security matrix uses a bounded connector-free table with declaration-ordered
roles and components and exactly one authored permission at every intersection.
The explicit level alone selects category treatment and its default label;
`unknown` remains distinct from denial, and omission fails. Optional role codes,
component hints, and one focal annotation remain literal. Status remains partial
with no verified variants; see the [access-matrix guide](../access-matrices.md).

## 0.20.0 ER parity boundary

ER uses dedicated conceptual entities and declaration-ordered fields, with
explicit neutral relationships and exact cardinality at both authored
endpoints. Primary/foreign glyphs record only author-supplied field
classifications; no relationship, physical foreign key, SQL type, or deletion
action is inferred. Natural card heights, distinct ports, masked labels, and
actionable layout failures preserve the bounded geometry. Status remains
partial with no verified variants; see the [entity-relationship guide](../entity-relationships.md).

## 0.21.0 database-schema parity boundary

Database schema uses dedicated physical tables and table-scoped columns, with
literal SQL types, explicit constraint chips and named indexes, and foreign
keys attached to their exact source and target rows. Each FK requires a source
`FK`, target `PK`/`UQ`, and one explicit deletion action. Multiple cascades are
preserved and accent their dependent source-table headers; referenced parents
and other actions remain neutral. Measured cards, explicit schema groups,
symmetric in-row ports, orthogonal rounded routes, masked action labels, and
actionable layout failures preserve the bounded geometry. Status remains
partial with no verified variants; see the [database-schema guide](../database-schemas.md).

## 0.22.0 UML-class parity boundary

UML class diagrams use dedicated `class`, `abstract_class`, and `interface`
records with literal attribute and operation strings. Six explicit relation
kinds preserve hollow target triangles, declared-owner filled/hollow diamonds,
plain undirected associations with exact multiplicities, and dependency-only
open arrows. Natural compartments, actual card endpoints, distinct ports,
exterior corridors, masks, a complete legend, and the shared 1.5× readable
scale preserve the bounded geometry. Status remains partial with no verified
variants; see the [UML class guide](../uml-classes.md).

## 0.23.0 Quadrant parity boundary

Quadrants use dedicated literal low/high axis records and two to twelve item
records with finite authored x/y coordinates. The measured 720×480 plot maps
coordinates exactly within `[-1,1]` outside the central safety band. Labels
must stay wholly in their authored quadrant and clear axes, dots, labels, and
bounds; rendering fails rather than moving a point. One optional focal item is
an author-selected discussion point. The visible and accessible caption says
positions are qualitative judgments rather than calculated scores, and the
logical 8px axis role renders at 1.5×. Status remains partial with no verified
variants; see the [Quadrant guide](../quadrants.md).

## 0.24.0 Venn parity boundary

Venn diagrams use dedicated immutable set and intersection records. Exactly two sets require their sole pair; exactly three sets require every pair and the triple. Fixed equal circles preserve named topology without encoding area, population, counts, or weights. Set and overlap labels are measured in fixed clear regions, one optional focal overlap is author-selected, and geometry fails rather than resizing circles or changing membership. Status remains partial with no verified variants; see the [Venn guide](../venn.md).

## 0.25.0 Loop parity boundary

Loop diagrams use one shared-state hub and five to eight dedicated stations. A mandatory clockwise `cycle` preserves authored display order and declares adjacent arcs plus closure; exactly one authored write-back per station declares every radial spoke. The fixed measured cards, same-radius arcs, 6px hub gap, one optional focal station, strict Ruby/JSON parity, and explicit layout failures form the bounded contract. Counterclockwise flow, branching, skips, implicit relations, multiple hubs, and custom geometry remain outside the slice. Status remains partial with no verified variants; see the [loop guide](../loops.md).

## 0.26.0 Fishbone parity boundary

Fishbone diagrams use one literal observed effect and two to five dedicated categories with one to three ordered factor strings each. Explicit upper/lower side assignment, at most three categories per side, fixed side slots, exact 60-degree bones, 32px ticks, measured tags, and a 200px effect head form the bounded contract. A third lower category moves the head and widens the viewBox together. Factors are investigated or associated leads and never causal proof; confirmed-root, confidence, probability, blame, focal, arbitrary geometry, and chronology semantics remain outside the slice. Status remains partial with no verified variants; see the [fishbone guide](../fishbones.md).

## 0.27.0 Wardley parity boundary

Wardley maps use two to nine dedicated components in four qualitative evolution bands with explicit finite visibility, plus one to twelve explicit value-chain dependencies that make every component incident. Straight muted dependencies have no arrows or runtime meaning. Up to two strictly adjacent rightward movements use dashed accent arrows. The fixed 960px plot, 12px logical text floor, stacked visibility phrases, qualitative labels, fixed caption, strict Ruby/JSON parity, and collision failures form the bounded contract. Scores, free positions, numeric ticks, inferred dependencies, focal fields, labels, icons, custom colors, and architecture semantics remain outside the slice. Status remains partial with no verified variants; see the [Wardley guide](../wardley-maps.md).

## Delivery waves

| Wave | Scope | New types | Cumulative type coverage target |
| --- | --- | ---: | ---: |
| Foundation | Bring the six current types toward conformance; theme registry; RSpec visual/geometry fixture harness; standalone examples and clean-install CI; public CLI | 0 | 6 |
| Topology and hierarchy | Dependency (bounded 0.8.0 slice), deployment (bounded 0.9.0 slice), IT current-state (bounded 0.10.0 slice), high-level, tree, nested, layers, pyramid, medallion | 9 | 15 |
| Workflows and platforms | Swimlane, process, Gantt, kanban, user journey, story map, data flow, DP integration, DP security matrix | 9 | 24 |
| Models and strategy | ER (bounded 0.20.0 slice), database schema (bounded 0.21.0 slice), UML class (bounded 0.22.0 slice), quadrant (bounded 0.23.0 slice), Venn (bounded 0.24.0 slice), Loop (bounded 0.25.0 slice), Fishbone (bounded 0.26.0 slice), Wardley (bounded 0.27.0 slice) | 8 | 32 |
| Quantitative charts | Bar, line, scatter (bounded 0.28.0 slices); treemap and Sankey (bounded 0.29.0 slices); radar and polar (bounded 0.30.0 slices) | 7 | 39 |
| Workflow completion | Importers, fidelity report, semantic patterns, brand profiles, size presets, PNG output, optional motion and remaining special variants | — | All requirements audited |

The ordering groups reusable primitives; it is not a time estimate. Each wave ends in a rendered gallery, not just a list of accepted type names.

Quantitative types require tests of what the graphic claims: zero baselines where appropriate, axis units and domains, area/radius encodings, flow conservation, empty/negative/zero inputs, and label placement. Treemap and Sankey need their own algorithms. ER cardinality, SQL foreign keys to exact columns, and UML relationship markers are three distinct contracts.

## Definition of parity

Each of the 39 types gets at least the upstream minimal light, minimal dark, and full editorial reference cases: 117 baseline cases, plus the documented type-specific variants. For every case retain:

- Source reference at the pinned revision and matching semantic fixture.
- Executable Ruby DSL, with no author-written coordinates.
- A rendered result and a human visual review at appropriate sizes.
- RSpec evidence for defining geometry/data semantics, accessibility, and relevant edge cases.
- Export and integration evidence where the capability changes those paths.
- Explicit status: missing, partial, or verified. A known deviation blocks parity unless it is a deliberate, documented product decision preserving the same meaning.

Use upstream validators where applicable, along with independent RSpec checks. Pixel snapshots detect unintended changes in our own output; they cannot alone establish semantic equivalence to hand-authored upstream diagrams.

## Themes without a breaking API

The existing `theme: :light/:dark/:auto` means color mode. Keep it working and introduce an independent style preset:

```ruby
# Available since 0.2.0
SlimGraphR.diagram :architecture,
  title: 'Request handling', style: :ruby, theme: :dark do
  external :client
  node :api, 'API', emphasis: true
  store :database
  flow :client, :api, :database
end
```

| Proposed style | Direction | Primary use |
| --- | --- | --- |
| `:editorial` | Faithful reference-derived skin, including its typography; documented accessibility adjustments | Upstream comparison and long-form explanation |
| `:ruby` | Warm ivory, ink, deep ruby red; welcoming detail with confident headings | SlimGraphR's own identity and default candidate |
| `:blueprint` | Technical blue/ink, precise linework, restrained emphasis; avoid decorative graph-paper backgrounds | Engineering diagrams |
| `:mono` | Black/white/gray with stroke, weight and pattern carrying emphasis | Print and neutral embedding |

The four named styles ship in 0.2.0; editorial remains the compatible default. A default change remains open for review. Avoid a `:rails` preset name implying an official affiliation; draw from the site's confidence and visual discipline instead.

A style contains semantic colors, typography roles, stroke/radius tokens, and marker treatments. Color mode selects its light/dark values. Diagram semantics and quantity scales stay independent. Font changes must feed label measurement and layout; a theme cannot be only a late CSS paint pass. User overrides should form a validated profile, not bypass contrast or focal-budget checks. Resolve and embed style tokens into SVG so exported artifacts stay portable.

Presentation (minimal/full editorial), output size, content detail and audience are separate concepts. Add only the dials needed by each capability, with good defaults. Do not turn an elegant Ruby block into a bag of configuration flags.

## Brand and README direction

Reviewed the actual hero images and opening copy from Tyrion, StreamWeaver, iterm2_ruby and uregistry. Their common pattern is a concrete story about what the tool does: a war-room ledger, UI chaos becoming a concise declaration, finding a terminal amid agent overload, and consulting a verified reference instead of memory. The graphics carry the mechanism and the writing has a point of view.

The current Ruby homepage combines warm paper, red, and playful human illustration. The current Rails homepage combines strong red/black typography, direct assertions, and a code-first value proposition. SlimGraphR can draw on both without reusing their logos or pretending affiliation.

Recommended direction: a Ruby print shop. A small, beautifully engineered red drafting press turns a tiny description into a clear diagram. It is expressive enough for a README but rooted in the product's mechanism. Keep the generated hero separate from the real output gallery: illustration sells the idea; renderer-produced SVG proves it.

Draft image: `assets/concepts/ruby-press-v1.png`. Built-in image generation; exact prompt in the adjacent `.prompt.txt`. It is a concept for review, not a committed brand/default theme. The image's drawn graph is illustrative, not a sample output or fidelity claim.

Potential README opening lines for review:

- “You describe the system. Ruby draws the damn diagram.”
- “Stop paying a language model to count pixels.”
- “A little Ruby. A lot more clarity.”

The second is a provocation, not a benchmark claim. Back it immediately with executable DSL, actual output, and a measured comparison that distinguishes source token counts from model billing.

README order: strong original hero → short product claim → real DSL beside real output → immediate install/run → 39-type coverage table with honest statuses → integrations → benchmark method → prominent inspiration/credit and contribution guidance.

## Foundation progress and next implementation slice

1. Done in 0.2.0: standalone/StreamWeaver examples, CLI with Ruby and JSON input, isolated package checks, and CI configuration. Hosted CI awaits a repository push.
2. Done in 0.2.0: four style presets and independent light/dark/auto mode, with contrast checks and heading-aware wrapping.
3. Close shared connector gaps and type-specific gaps in the nineteen implemented renderers, including the bounded pyramid, medallion, Gantt, and Kanban slices.
4. Review identical diagrams in the proposed styles; choose the default and hero direction.
5. Deliver the remaining type families against the conformance matrix.

## Sources

- https://github.com/cathrynlavery/diagram-design/tree/dcd9317ed9ec7477b20005544f36e3313664d815
- https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/SKILL.md
- https://www.ruby-lang.org/en/
- https://rubyonrails.org/
- Local README references: Tyrion, StreamWeaver, iterm2_ruby, uregistry, as requested by the user.
