---
name: SlimGraphR
description: Intent-first Ruby diagrams with five curated visual styles.
colors:
  paper: "#f5f5f5"
  secondary: "#ececec"
  ink: "#2d3142"
  muted: "#4f5d75"
  rule: "#bfc0c0"
  accent: "#a83f18"
  tint: "#f8e7df"
  dark-paper: "#2d3142"
  dark-secondary: "#393e53"
  dark-ink: "#f5f5f5"
  dark-muted: "#bfc0c0"
  dark-rule: "#626b80"
  dark-accent: "#ffa374"
  dark-tint: "#493c3b"
  ruby-paper: "#faf6ee"
  ruby-secondary: "#f0e9de"
  ruby-ink: "#241d1d"
  ruby-muted: "#625353"
  ruby-rule: "#baaba5"
  ruby-accent: "#ad1733"
  ruby-tint: "#f5e2e4"
  ruby-dark-paper: "#211a1d"
  ruby-dark-secondary: "#30272b"
  ruby-dark-ink: "#fff7ee"
  ruby-dark-muted: "#d1bfc4"
  ruby-dark-rule: "#74616a"
  ruby-dark-accent: "#ff93a6"
  ruby-dark-tint: "#42252f"
  blueprint-paper: "#f4f8fc"
  blueprint-secondary: "#e5edf5"
  blueprint-ink: "#132d47"
  blueprint-muted: "#3d5972"
  blueprint-rule: "#9eb3c9"
  blueprint-accent: "#145da0"
  blueprint-tint: "#ddeaf8"
  blueprint-dark-paper: "#102438"
  blueprint-dark-secondary: "#1a334b"
  blueprint-dark-ink: "#f1f7ff"
  blueprint-dark-muted: "#bbd0e3"
  blueprint-dark-rule: "#59758e"
  blueprint-dark-accent: "#88c8ff"
  blueprint-dark-tint: "#203f5b"
  mono-paper: "#ffffff"
  mono-secondary: "#eeeeee"
  mono-ink: "#202020"
  mono-muted: "#555555"
  mono-rule: "#aaaaaa"
  mono-accent: "#111111"
  mono-tint: "#e2e2e2"
  mono-dark-paper: "#191919"
  mono-dark-secondary: "#292929"
  mono-dark-ink: "#f5f5f5"
  mono-dark-muted: "#cccccc"
  mono-dark-rule: "#737373"
  mono-dark-accent: "#ffffff"
  mono-dark-tint: "#383838"
  minimal-paper: "#ffffff"
  minimal-secondary: "#f6f7f9"
  minimal-ink: "#18212f"
  minimal-muted: "#52606d"
  minimal-rule: "#b8c2cc"
  minimal-accent: "#9f1239"
  minimal-tint: "#fce7ef"
  minimal-dark-paper: "#111827"
  minimal-dark-secondary: "#1f2937"
  minimal-dark-ink: "#f8fafc"
  minimal-dark-muted: "#cbd5e1"
  minimal-dark-rule: "#64748b"
  minimal-dark-accent: "#fda4af"
  minimal-dark-tint: "#4c1d2f"
typography:
  display:
    fontFamily: Instrument Serif, Georgia, serif
    fontSize: 30px
    fontWeight: 400
  title:
    fontFamily: Instrument Serif, Georgia, serif
    fontSize: 18px
  body:
    fontFamily: Geist, Helvetica Neue, Arial, sans-serif
    fontSize: 14px
  node-name:
    fontFamily: Geist, Helvetica Neue, Arial, sans-serif
    fontSize: 14px
    fontWeight: 600
  label:
    fontFamily: Geist, Helvetica Neue, Arial, sans-serif
    fontSize: 12px
  group-label:
    fontFamily: Geist, Helvetica Neue, Arial, sans-serif
    fontSize: 12px
    fontWeight: 600
  date:
    fontFamily: Geist Mono, ui-monospace, monospace
    fontSize: 12px
  ruby-display:
    fontFamily: Geist,'Helvetica Neue',Arial,sans-serif
    fontSize: 30px
    fontWeight: 700
  ruby-title:
    fontFamily: Geist,'Helvetica Neue',Arial,sans-serif
    fontSize: 18px
  blueprint-display:
    fontFamily: "'Geist Mono',ui-monospace,monospace"
    fontSize: 30px
    fontWeight: 500
  blueprint-title:
    fontFamily: "'Geist Mono',ui-monospace,monospace"
    fontSize: 18px
  mono-display:
    fontFamily: Geist,'Helvetica Neue',Arial,sans-serif
    fontSize: 30px
    fontWeight: 600
  mono-title:
    fontFamily: Geist,'Helvetica Neue',Arial,sans-serif
    fontSize: 18px
  frame-operator:
    fontFamily: "'Geist Mono',ui-monospace,monospace"
    fontSize: 12px
    fontWeight: 600
  frame-guard:
    fontFamily: "'Geist Mono',ui-monospace,monospace"
    fontSize: 12px
rounded:
  label: 4px
  node: 6px
  group: 8px
  terminator: 20px
  frame: 4px
spacing:
  grid: 4px
  node-inset: 20px
  component-margin: 32px
  title-inset: 40px
components:
  node:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.node}"
    typography: "{typography.node-name}"
  store:
    backgroundColor: "{colors.secondary}"
    rounded: "{rounded.node}"
  emphasis:
    backgroundColor: "{colors.tint}"
    textColor: "{colors.accent}"
    rounded: "{rounded.node}"
  edge-label:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.muted}"
    rounded: "{rounded.label}"
    typography: "{typography.label}"
  terminator:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.terminator}"
    typography: "{typography.node-name}"
  activation:
    backgroundColor: "{colors.secondary}"
    width: 8px
---

# Design System: SlimGraphR

## Overview

**Creative North Star: "Editorial diagrams"**

The approved diagram-design reference supplies the visual direction: light paper, slate ink, restrained orange emphasis, serif titles, sans-serif labels, thin rules, and rounded orthogonal connectors. This is a Read surface: understanding the depicted system is the goal.

Ruby owns placement and rendering; authors name the parts and relationships through a small, readable DSL. The emotional promise is relief from needless complexity: express the intent and let Ruby do the arrangement. The visual system is implemented in `lib/slim_graph_r/style.rb`, `lib/slim_graph_r/svg.rb`, and the layout classes. Executable galleries live in `examples/stream_weaver/gallery.rb`, `examples/stream_weaver/styles.rb`, and `examples/stream_weaver/flowcharts.rb`; standalone examples live in `examples/standalone`. Timeline examples are in `examples/stream_weaver/timelines.rb` and `examples/standalone/timeline_cases.rb`. Scoped sequence examples are in `examples/stream_weaver/sequences.rb` and `examples/standalone/sequence_frames.rb` and `examples/standalone/sequence_loop.rb`. Deployment examples are documented in `docs/deployments.md`; IT current-state examples are documented in `docs/it-current-state.md`. Preserve upstream attribution in `vendor/diagram-design`; full upstream visual parity is outside this release.

**Key Characteristics:**
- Restrained editorial hierarchy.
- Semantic emphasis with generous label space.
- Portable SVG with optional StreamWeaver integration.
- Bounded geometry with explicit layout failures.

## Colors

Five curated presets share semantic palette roles. Editorial remains the default: warm orange accent and pale tint on slate and paper. Ruby uses crimson and warm cream; Blueprint uses technical blues; Mono uses grayscale; Minimal uses cool white and slate with restrained crimson emphasis. Each provides paper, secondary store fill, ink, muted annotation text, rule, accent, and tint. Accent text meets a contrast ratio of at least 4.5:1 against paper and tint in all ten preset/mode combinations.

The frontmatter records actual palettes from `Style::PROFILES`. Unprefixed and `dark-` tokens belong to Editorial; other profiles use their name as a prefix, followed by `dark-` for dark mode. These are curated role sets, not a generated tonal scale.

**The Two Focal Points Rule.** Use at most two emphasized nodes or events in a diagram. Emphasis changes the node fill, outline, and name color, or the timeline marker size and title color.

Style and theme are separate choices: `style: :editorial`, `:ruby`, `:blueprint`, `:mono`, or `:minimal`, with `theme: :light`, `:dark`, or `:auto`. The default theme is light. Explicit dark uses the dark palette. Auto responds to the browser color preference and supported host theme selectors. SVG variables are scoped to each diagram ID so multiple diagrams can carry different themes on the same page.

Minimal uses a medium-weight sans-serif title, crisp 2px corners, a 16px node inset, one-pixel ordinary borders, two-pixel focal borders, and compact 3px/5px timeline markers. Its light and dark palettes are authored independently; it is not an editorial alias.

## Typography

Editorial pairs serif display titles with sans-serif node names and annotations. Ruby uses bold sans-serif display titles, Blueprint uses medium-weight monospace, and Mono uses semibold sans-serif. Timeline event titles follow each preset's heading family at their own smaller size; they do not inherit the display title weight. All presets share the same sans-serif body stack, and dates retain a technical monospace stack. Node details and connector labels use the smaller label role; timeline detail text uses the body role.

**The Local Fonts Rule.** Fonts are optional local preferences, never a rendering network dependency. Instrument Serif falls back to Georgia; Geist to Helvetica Neue and Arial; Geist Mono to system monospace. Verify the gallery with fallback fonts.

Text wraps using conservative width estimates, not browser font measurement. The selected `heading_font` drives diagram-title and timeline-title width estimates before layout, including the wider monospace profile. SVG line advances are explicit: diagram titles (36px), node names (20px), details and labels (16px), timeline titles (24px), and timeline details (20px). A long label can enlarge a box; text is not silently clipped to retain a preferred shape.

## Layout

Architecture defaults to a rightward layered graph; flowcharts and org charts default downward. Ordinary graph nodes start at a minimum size of (224 × 88px), growing with text or connection degree. Flowchart start and finish nodes start at (224 × 64px); decision diamonds begin at (288 × 144px) and grow to contain centered text inside their sloping boundaries. Merge junctions occupy (8 × 8px). Placement rounds to the grid. Grouped nodes occupy lanes; group labels reserve their own header space. Architecture and flowchart groups cannot nest.

Dependency graphs default downward with ranked rows (120px) apart and fixed node boxes (160 × 56px). Internal, external, and leaf treatments remain distinct; external treatment takes precedence when an external node is also a leaf. Every node receives a computed fan-in badge. A marked cycle runs through an outside lane, leaving its endpoint nodes in their normal treatments. The bounded dependency model allows 9 nodes, 14 relationships, four ranks, one marked cycle, and two accent elements.

Sequence diagrams use participant columns (272px apart), participant boxes (208px wide), dashed lifelines, and messages in author order. Self-messages use a U-shaped path with the label beside its outer edge. Long message labels wrap between adjacent lifelines, including messages spanning several participants. Scoped activation bars attach message endpoints to their visible boundaries; sibling scopes stay disjoint. Date-scaled timelines use a horizontal elapsed-day axis (800px) within a (1140px) scene. Dates require complete, valid Gregorian `YYYY-MM-DD` strings. Events sort chronologically, preserving input order for the same date. Each distinct date keeps its exact linear position; same-date events share one marker and a grouped callout. A single distinct date has a centered marker and a zero-length domain.

**The Faithful Calendar Rule.** Never nudge markers apart to make labels fit, and never insert axis breaks. Callouts measure text within (224px), alternate above and below the axis, and add rows when needed. Leaders route around callout text and sparse actual-date tick labels. Distinct markers less than (12px) apart or callouts that cannot route clearly raise actionable density errors; split the timeline or explicitly choose ordered mode. This replaces the earlier minimum-spacing marker adjustment, which distorted elapsed time.

Timeline `scale: :auto` selects date mode only when every date is valid; otherwise it uses ordered mode. Explicit `:date` rejects invalid dates. Explicit `:ordered` preserves author order in a vertical (704px) scene, with a visible and accessible note that spacing does not measure time. Constructor, `with`, and CLI scale validation preserve these choices.

**The Scoped Sequence Rule.** Sequence diagrams allow at most five participants and twelve messages. `activate` scopes nest up to three levels per participant. Use one `alt` frame with exactly two guarded `branch` regions, or at most two `opt`/`loop` frames. Frames cannot nest; each region and activation must contain a message, and guards cannot be blank. Participants touched by a frame must be adjacent in declaration order; otherwise layout raises an actionable error. `loop` describes repetition without executing its body repeatedly.

**The Bounded Ownership Rule.** Org charts use a downward graph by default. `owner` names an accountable person or team through the existing node label slot; `invoke`, `scope`, `detail`, and `unavailable` are measured as separate semantic text roles. Generic `node` calls remain valid for org charts and accept the same ownership fields. A child has at most one incoming reporting edge, cycles fail during construction, and disconnected roots remain valid forests. The org-specific budgets are 12 visible nodes, four tiers with the root as tier 1, five direct reports per parent, one emphasized node, and two combined escalation/approval callouts. These limits bound layout; they do not guarantee every chart will fit without a split.

`escalation` and `approval` create rule records, not graph nodes. The renderer places them after a divider in a footer strip and reserves that strip as blocked geometry so reporting connectors stay above it. `unavailable: true` keeps the owner visible with a setup-needed treatment. Ruby and strict JSON use the same model, and generated descriptions retain names, invocation routes, scopes, unavailable state, reporting edges, and rules.

**The Bounded State Rule.** State diagrams use rounded state boxes, a filled entry dot, ringed final dots, curved transition paths, an outside feedback lane for the one permitted multi-state cycle, and a loop above a state. `event [guard] / action` is measured in the monospaced label role. The dedicated model requires two to twelve states, one initial, one or two finals, lifecycle reachability from the initial to every state and from every state to a final, and explicit transition/degree/pair/cycle budgets. A dense scene may raise `LayoutError` when a route or label cannot be separated clearly; the renderer preserves meaning by refusing an unclear layout. Composite/history states, forks, anonymous transitions, nested or overlapping cycles, and “from any state” arrows are outside this slice.

**The Bounded Dependency Rule.** Dependency arrows run from dependent to requirement. A shared requirement or one real cycle gives this type its meaning; one-parent branching data uses `:tree` with nested `root`/`child` blocks. Rank rows are 120px apart, nodes are fixed 160×56px boxes, and fan-in is computed from every relationship, including the marked cycle. Internal, external, and leaf boxes use separate treatments; external metadata shows version and registry. Only one marked cycle is accepted, and its outside dashed accent lane plus `CYCLE` label are the two accent elements. Ordinary dependency paths cannot double back upward; congestion or an unplaceable connector/label raises `LayoutError` rather than producing an unclear scene. Groups, emphasis, and arbitrary generic labels are rejected.

**The Bounded Deployment Rule.** Deployment diagrams use three containment levels: meaningful zones contain typed infrastructure nodes, and nodes contain versioned artifact chips. The approved constructors are `host`, `vm`, `pod`, `managed`, and `cdn`; `replicas:` is a positive integer defaulting to one, and `emphasis:` is a strict boolean. Paths require protocol and port; internal routes use muted treatment, cross-zone routes use the style's link role (link blue in Editorial and Ruby, a separate link shade in Blueprint, and an ink adaptation in Mono), and `async: true` uses a `5,4` dash. `emphasis: true` overrides the ordinary node or path treatment with the accent role and counts toward the combined two-element focal budget. Zones are measured columns with a reserved 40px header; nodes measure labels/chips, carry rectangular type tags and `xN` badges only when `N > 1`, and chips are 24px high with an 8px stack gap. The bounded budgets are 3 zones, 6 infrastructure nodes, 9 artifact chips, 8 paths, and two combined emphasized nodes/paths. Unknown or invalid content and unplaceable paths or labels raise explicit errors rather than clipping or inventing placement. This remains bounded partial parity against the pinned upstream deployment reference.

**The Bounded IT Current-State Rule.** IT current-state diagrams use a horizontal sequence of 2–4 phases, each containing 1–5 named systems. Systems carry measured technical details and one of `standard`, `external`, or `pain_point` state; a pain point gives every touching handoff the effective accent treatment. Labelled handoffs use `neutral`, `link`, or `accent` style and an independent boolean `dashed` flag; `dashed: true` draws a dashed line and does not imply a separate `manual` field or any medium/external semantic. Source order determines forward/backward direction, and a backward handoff requires an external endpoint plus `dashed: true`. Crosscut services render as footer bars without graph endpoints. Budgets are 16 systems, 24 handoffs, two pain points, and three crosscuts; phase labels are uppercase and at most 14 characters, handoff labels uppercase and at most 8. Subtitle and eyebrow are optional. Used semantics drive a curated legend. Vertical layout, icons, custom colors, side overrides, caller legends, and full editorial framing remain outside this bounded partial slice; invalid content or an unplaceable route/label raises an explicit error.

**The Bounded High-Level Rule.** High-level diagrams use a dedicated horizontal data-stack model: 3–5 phase chevrons, a dashed first-phase source zone, a solid cluster boundary labelled `Cluster` by default, 152×80 component boxes aligned to phase centers, an optional orchestration bar, and concern-paired crosscut rows in a reserved 28px right strip. `connect(from, to)` is an unlabeled forward interphase data link. Exactly one component is explicitly focal. Orchestration defaults to concern `Orchestration`; bar-originating trigger styling wins when a trigger targets the focal node, while other focal-touching data links use the effective `primary` treatment and ordinary links use `secondary`. Each crosscut requires a distinct concern and pairs automatically. Orchestration targets must be the top component in their phase so a straight trigger drop remains visible. Reserved concern labels cannot be horizontal phases. Phase and vertical concern labels are uppercased for display and measured for fit. Icons, manual vertical concerns, labels, query/backward/same-phase links, custom colors, and editorial-card variants remain outside this bounded partial slice; impossible geometry raises `LayoutError`.

**The Bounded Tree Rule.** Tree diagrams use one nested `root` and direct `child` declarations. The root is tier 1; depth is limited to four tiers, each tier has at most five nodes, and each parent has at most five direct children. Focal treatment is optional and limited to one node. Downward and rightward layouts use orthogonal parent stems, sibling buses, and child drops drawn behind 120–180px rounded node boxes. Tree JSON uses the recursive `root` schema and rejects skipped tiers, duplicate IDs, and cross-type fields. This remains bounded partial parity against the pinned tree reference.

**The Bounded Nested Rule.** Nested-containment diagrams use one uninterrupted chain of 3–5 scopes with fixed `:down` direction. Regular 28px horizontal and 34px vertical insets, paper-masked top labels, progressively stronger strokes, and automatic accent/tint on the innermost scope preserve containment. The bounded outer ring is 880px wide; labels that cannot fit raise `LayoutError`. Branching scopes, sibling content, icons, annotations, and unrestricted depth remain outside this partial slice.

**The Bounded Layer Rule.** Layer stacks use 4–6 author-ordered equal 64px bands within an 800–880px measured stack, with index, name, and detail columns and an external axis arrow. `axis` defaults to `Abstraction`; `indicator` defaults to `:up` and accepts `:down`. Exactly one layer is focal. Numeric indices must be one contiguous ascending or descending sequence with no gaps; all-semantic indices may be unique, but numeric and semantic forms cannot be mixed. Variable-height bands, icons, gradients, and complete OSI coverage remain outside this partial slice.

**The Bounded Cartesian Rule.** Bar, line, and scatter use dedicated immutable quantitative records and finite linear BigDecimal arithmetic. Bar compares 2–12 ordered categories from exact zero, with no painted rectangle for zero. Line keeps 1–4 series complete across 3–24 required elapsed-day or explicit ordinal positions; a declared gap disconnects straight segments. Scatter positions 2–30 complete points on two required explicit scales and adds at most three measured annotations. Numeric labels use renderer-owned plain half-even formatting at precision 0–6. Visible captions, descriptions, and SVG metadata disclose domains, units, ordinal spacing, gaps, and deterministic constant-data reference domains. Text is measured before marks; labels are sparsified without moving data, and unresolved interference raises an actionable `LayoutError`. Log scales, splines, jitter, trend lines, bubble size, clipping, snapping, and fabricated minimum marks remain outside this bounded partial slice.

**The Bounded Area Rule.** Treemaps accept 2–12 unique nonnegative items with at least one positive value and at most one focal border. Positive items form one unsnapped squarified rectangle whose exact area shares use original BigDecimal values. Zero remains visible in the legend and description but owns no cell. Tiny positive cells keep their area and use a keyed external legend. Gutters, minimum areas, logs, stripes, dropped items, and invented aggregates are forbidden.

**The Bounded Conservation Rule.** Sankeys declare exactly three stages, 3–10 positive nodes, and 2–16 positive adjacent-stage flows. Every node and stage balances exactly. One finite pixels-per-unit scale drives all bar heights and fractional ribbon thicknesses; nonoverlapping offset intervals meet bars horizontally. A subpixel band raises an actionable layout error. Loss, waste, injection, or aggregation must be explicit authored nodes and flows; the renderer infers none.

**The Bounded Pyramid Rule.** Pyramid diagrams have explicit `orientation: :pyramid` or `:funnel` and `mode: :hierarchy` or `:measured`, with both defaults shared by Ruby and JSON. Hierarchy is a four-to-six-level ordinal taper and is upward only; it makes no quantity claim. Measured mode requires a shared unit, a positive initial boundary, finite nonnegative chained `from`/`to` values, `to <= from`, and exact shared boundaries. Equal-count plateaus, conversion to zero, and subsequent `0 → 0` tails remain honest. Boundary widths are proportional with no readability floor; narrow labels use collision-free outside leaders and an unfaithful scale, route, or serialized coordinate raises `LayoutError`. One optional focal level is allowed, never at the base. Decorative numeric funnels, authored axes/drop-off annotations, mixed orientations, and arbitrary coordinates remain outside this bounded partial slice.

**The Bounded Medallion Rule.** Medallions use 3–6 fixed 172×380px cards in left-to-right promotion order, cubic adjacent arcs over an 80px top band, and zero to two measured write-path cards. Exactly one tier is focal; archive is optional, final-only, and never focal. Promotions cover every adjacent pair exactly once. At most two tiers or paths may use a semantic `security`, `quality`, `product`, or `analysis` concern; arbitrary colors are rejected. Incoming concern styling matches the target, focal styling wins, and archive landing uses the dashed lifecycle treatment. Card fields use measured two-line `<tspan>` lanes; tags, titles, and details in a write path retain distinct measured spacing. Non-adjacent/backward/bidirectional flows, custom arcs, and arbitrary coordinates remain outside this bounded partial slice.

**The Bounded Workflow Rule.** Swimlane and process diagrams use dedicated horizontal actor lanes with a 140px actor column, 112px stage columns, 80px lanes, and measured 100×64px cards. Stages number contiguously and cards occupy one explicit `(lane, stage)` cell; empty cells render nothing and remain meaningful in accessible descriptions. Ordinary forward handoffs render behind cards: adjacent same-lane routes are horizontal, while cross-lane routes exit right and enter the destination top or bottom with one soft bend. Swimlanes allow one optional focal handoff. Process lanes require unique 1–3 character keys, tools remain in cards and descriptions, and the legend reports numbered/focal steps, used payload codes, and effective flow semantics. Process operations accept only `LS`, `DB`, `TB`, `FL`, or `WB` payload codes; omitted or null values are unknown, supplied first-stage inputs or last-stage outputs are rejected, and no handoff payload equivalence or conversion is inferred. Exactly one stage and operation are focal. One optional labelled backward trigger uses a reserved return band and a three-bend route; it is always neutral and dashed, overriding focal styling. The bounded budgets are 1–6 lanes, 1–12 stages, 24 cards, 24 ordinary handoffs plus one optional trigger, and one card per cell. Same-stage/backward ordinary edges, conversions, parallel gateways, custom colors, icons, vertical lanes, and arbitrary coordinates remain outside this partial slice; invalid content or unplaceable measured routes/labels raises `LayoutError`.

**The Bounded Planning Board Rule.** Gantt is a static author-supplied calendar plan: phases contain declaration-ordered tasks, tasks use complete Gregorian all-day dates as exact half-open `[start, finish)` intervals, and top-level milestones and muted static markers remain point records. The visible and accessible caption says that the finish date is excluded. The 180px label column, 760px elapsed-day timeline, 40px task rows, exact 24px bars, phase tracks, sparse year-aware ticks, and fixed point coordinates preserve date meaning; under-one-pixel bars, unplaceable labels, or overlapping same-track milestone diamonds raise `LayoutError`. Same-date milestones on separate tracks remain exact, while close marker lines may render when measured geometry is clear. Gantt allows 0–4 phases, 0–12 tasks, 0–8 milestones (at least one when no tasks), 0–2 markers, and one focal task. Dependencies, progress, critical path, baselines, recurring work, automatic today, axis breaks, and inferred phases are outside this slice.

Kanban is a static author-supplied work-state census: 2–5 declaration-ordered columns contain 0–4 declaration-ordered cards each, with an overall 12-card layout budget. Cards preserve optional ticket/owner metadata and neutral/default, blocked, waiting, or done state; columns derive actual counts, and a supplied positive WIP limit renders honest `n/limit` violations. Empty columns, multiple blocked cards, and over-limit data remain visible. Blocked/waiting/done treatments and WIP violation chips coexist with one optional focal card's ink ring; no connectors, sorting, inferred state, aggregation, or silent WIP repair is allowed. Fixed 240px columns, 32px gutters, 56px cards, 12px gaps, and measured wrapped text raise `LayoutError` when the bounded scene cannot fit. An author description replaces generated accessibility prose for either board type; otherwise descriptions report the authored records and effective semantics.

**The Bounded Journey Rule.** User journeys describe one named person or role through 2–6 declaration-ordered stages. Every stage has one action and one explicit ordinal sentiment from `high`, `medium_high`, `neutral`, `medium_low`, or `low`; touchpoints are optional. Exactly one stage must be the unique lowest-sentiment trough, and at most two pain markers may appear on that trough. The 64px left row-label minimum is measured against tracked labels (the current `TOUCHPOINTS`/level labels resolve to an 84px margin), followed by 200px stage columns, 24px gutters, and 4px right stroke padding. Dots remain on their authored ordinal levels; the single curved line conveys sequence only and never interpolates a score. Numeric sentiment, ties, inferred personas, multiple curves, state/WIP, arrows, and generic process flows are outside this bounded partial slice. Density or measured label failures raise `LayoutError`, and custom descriptions replace generated descriptions exactly.

**The Bounded Story Map Rule.** Story maps describe one named person or role through 2–5 declaration-ordered activities, each with 1–2 steps, and 2–3 declaration-ordered release bands. Every release has at least one story referencing an existing activity. Exactly one release has `cut: true`, it is not final, and at most one story has `risk: true`. `estimate:` and `ticket:` are authored nonblank metadata; release labels are literal text even when date-like and carry no calendar semantics. The fixed layout uses a 96px release-label margin, 200px activity columns, 24px gutters, and 16px right stroke padding, with 56px backbone cards, up to two 32px step cards, and 48px story cards. The 12-story total and four-per-release budgets bound layout; no sorting, aggregation, cross-activity cards, dependencies, sentiment, state, or priority inference is allowed. Density or measured label failures raise `LayoutError`, and custom descriptions replace generated descriptions exactly.

**The Bounded Data-Flow Rule.** Data-flow diagrams use a horizontal role × stage grid: a measured role-label column, 168px step slots, a 40px outer right margin, a 36px step header, and 88px role bands. Transfers occupy fixed 152×72px cards in one declared `(role, step)` cell, require a tool, and may carry explicit input/output payloads from `web`, `dataset`, `table`, `file`, or `stream`; omitted sides remain undeclared. Handoffs use only `ordinary`, `trigger`, `focal`, or `publish`: ordinary/publish routes advance to a later step, triggers are unlabelled same-step downward role handoffs, and the focal handoff crosses roles and targets the focal transfer in the focal step. Exactly one linked focal step/transfer/handoff claim is required. Orthogonal routes use distinct ports and at least 12px separation; the focal label has an 8px masked gap. The bounded budgets are 2–4 roles, 2–6 steps, 2–16 transfers, and 20 handoffs. Unknown fields, nulls, arbitrary colors/icons/coordinates, inferred conversions, and unplaceable text or routes raise explicit errors. This remains bounded partial parity against the pinned upstream data-flow reference.

**The Bounded DP-Integration Rule.** Platform-integration diagrams use one bordered platform zone with declaration-ordered sources, consumers, platform bars and one service row, plus a measured footer-card strip for layer-wide services. Sources, consumers, and layer services use closed kind vocabularies; wires are explicit and use `ordinary`, `federated`, `trigger`, or `serve`. Ordinary wires retain the neutral treatment, triggers have no protocol label, and serve wires originate only at the single serving component. The fixed 1200px read surface uses 160×64px side cards, measured bands, distinct boundary ports, and at least 8px protocol-label clearance; footer cards stay in one strip. The bounded budgets are 0–6 sources, 0–6 consumers, 2–6 platform components, 0–3 layer services, and 20 wires, with exactly two focal components and one serving component. Unknown, inferred, direct layer-service/component, or unplaceable content raises `LayoutError`. This remains bounded partial parity against the pinned DP-integration reference.

**The Bounded Access-Matrix Rule.** DP security matrices are connector-free role × component tables with one explicit permission for every declared pair. The five closed levels are `admin`, `write`, `read`, `deny`, and `unknown`; denial and unknown remain visibly distinct, and omission is invalid. Optional role codes and component hints remain authored metadata. A deterministic display label comes only from an explicit level and may be replaced literally. Zero or one focal cell may carry the only note, without changing its level. Measured component and role columns, 56px body rows, uppercase tracked headings, and a used-level legend widen or grow the canvas within budgets of 2–5 roles, 2–10 components, and 4–36 cells. Unplaceable text raises `LayoutError`; the renderer never clips, drops, substitutes, inherits, or infers a permission. This remains bounded partial parity against the pinned DP-security-matrix reference.

**The Bounded ER Rule.** Entity-relationship diagrams use dedicated immutable entities, declaration-ordered conceptual fields, and explicit entity-to-entity relationships. Fields render in natural-height 20px rows under a 28px `ENTITY` header; authored primary and foreign classifications render `#` and `→` without inferring a target, SQL type, physical foreign key, or deletion behavior. Relationships preserve exact `1`, `N`, `0..1`, `0..*`, and `1..*` tokens at their authored endpoints, use neutral orthogonal rounded paths with distinct ports, and never acquire arrows. Cardinality and relationship-label masks preserve endpoint and line clearance. The bounded model accepts 2–6 entities, 1–6 fields per entity, 1–8 relationships, and zero or one focal entity. Self-relations, groups, physical schema facts, and unplaceable text or geometry fail explicitly. This remains bounded partial parity against the pinned ER reference.

**The Bounded Database-Schema Rule.** Database-schema diagrams use dedicated immutable tables, table-scoped columns, and exact foreign-key records. Measured 240–304px cards have a 32px `TABLE` header, fixed 24px column rows with literal constraint chips and right-aligned SQL types, and an optional named-index compartment. Explicit schemas alone create dashed containment groups. Foreign keys attach to their named source and target rows, fan symmetrically inside a shared row, and use orthogonal rounded routes with masked action labels. A foreign key requires a declared source `FK`, target `PK`/`UQ`, and one explicit `cascade`, `restrict`, `set_null`, or `no_action` action; no type, constraint, index, schema, nullability, action, or endpoint is inferred. Every cascade uses accent treatment and tints its dependent source-table header; referenced parents and other actions remain neutral. The bounded model accepts 2–5 tables, 1–8 columns and 0–3 named indexes per table, and 1–6 foreign keys. Generated DDL, dialect validation, composite keys, database dumps, arbitrary coordinates, and unplaceable geometry fail explicitly or remain deferred. This remains bounded partial parity against the pinned database-schema reference.

**The Bounded UML-Class Rule.** UML class diagrams use dedicated immutable class and relation records. `class_type`, `abstract_class`, and `interface` cards contain only authored attribute and operation strings, in natural-height compartments; the renderer does not parse visibility, type signatures, or accessors. The six relation kinds are explicit. Inheritance and realization use target-end hollow triangles, composition and aggregation put a diamond at the declared owner endpoint, association is an undirected plain line with authored multiplicities at both ends, and dependency alone uses an open arrow. Routes use actual card bounds, distinct side ports, rounded orthogonal corridors, and opaque multiplicity masks. Logical 12px class names, 9px members, and 8px grammar roles render at the UML 1.5× readable scale, preserving the shared physical floor of 12px. The bounded model accepts 2–7 classes, 1–8 relations, five members per compartment, and zero or one focal class; unplaceable geometry raises a package-split error. This remains bounded partial parity against the pinned UML class reference.

**The Bounded Quadrant Rule.** Quadrants use dedicated immutable axis and item records. Literal low/high endpoint phrases surround a measured 720×480 2×2 plot. Every item has explicit finite x/y coordinates in [-1,1] and outside the absolute 0.08 central safety band. Coordinates map linearly without snapping, jitter, scoring, ranking, or collision movement. A measured label stays wholly in its authored quadrant and clears axes, dots, labels, and boundaries or raises an actionable `LayoutError`. Two to twelve items are allowed, with zero or one explicitly focal discussion point. The fixed visible and accessible caption states that positions are qualitative author judgments, not calculated scores. Consultant scenario cells, automatic placement, clusters, icons, custom colours, and grids beyond 2×2 are deferred. Logical 8px axis text registers a 1.5× readable scale, preserving a 12px physical minimum. This remains bounded partial parity against the pinned quadrant reference.

**The Bounded Venn Rule.** Venn diagrams use dedicated immutable set and intersection records for exactly two or three comparable conceptual sets. Two sets require their sole pair; three sets require every pair and the triple exactly once, so no visible overlap is unnamed. Intersection member order remains authored in descriptions while a canonical copy detects duplicate topology. Fixed equal circles encode topology only and make no area, population, count, weight, or percentage claim. Set labels stay outside strokes; measured pair/triple labels occupy fixed clear semantic regions, and one optional author-selected focal overlap receives a clipped accent tint. Unplaceable text raises an actionable `LayoutError` without resizing/repositioning circles, changing membership, or dropping regions. Weights, counts, radii, positions, colors, Euler fitting, omitted regions, automatic discovery, and four or more sets are deferred. Logical 14px region text registers a readable scale that yields a 16px physical minimum. This remains bounded partial parity against the pinned Venn reference.

**The Bounded Loop Rule.** Loop diagrams use one explicit clockwise cycle through five to eight dedicated stations around exactly one shared-state hub. The mandatory `cycle` names every station exactly once in displayed order, places its first ID at −90°, and explicitly authorizes each adjacent circular arc plus the last-to-first closure. Every station declares exactly one radial `write_back` to the hub; list syntax expands only named relations and never infers spokes. One optional focal station marks an author-selected operating gate, while the dark hub consistently means accumulated shared state. Measured 160×64 station cards and a 200×104 hub sit on a type-owned 240px radius; same-radius clockwise arcs trim to card boundaries and dashed radial write-backs stop 6px before the hub edge. Counterclockwise direction, skips, branches, multiple hubs/cycles/write-backs, implicit closure/spokes, custom coordinates/radii/paths, and cycles without shared state are deferred. Unplaceable text raises `LayoutError`, and the 12px logical metadata minimum meets the shared physical readability floor. This remains bounded partial parity against Cathryn Lavery’s pinned loop reference.

**The Bounded Fishbone Rule.** Fishbone diagrams organize literal investigated factors around exactly one observed effect. Two to five dedicated categories retain author order within explicit `above` or `below` slots, require one to three factors each, include at least one category on each side, and allow at most three categories per side and 18 factors total. Categories and factors are associated investigative leads, never proof of causation; root cause, confirmation, confidence, blame, probability, causal strength, focal treatment, arbitrary coordinates, colors, and cross-type records are rejected rather than inferred. A 1.2px horizontal spine lands at a measured 200px effect head. Category bones use the type's exact 60-degree exception and factor ticks are fixed 32px horizontal lines; all boxes and lines draw before text. Compact 280px/400px alternating slot cadence removes unoccupied spine travel; a third lower category widens the head position and viewBox together by 160px. Measured category, 12px factor, and effect labels must clear actual bounds and one another or raise `LayoutError` with split/shorten/widen advice. Fishbone uses the shared 16/14 display scale, producing a 1418px standard fixture and 1600px three-lower stress fixture. This remains bounded partial parity against Cathryn Lavery’s pinned fishbone reference.

**The Bounded Wardley Rule.** Wardley maps use dedicated immutable component and dependency records. Two to nine components require literal labels, one of four qualitative evolution bands (`genesis`, `custom_built`, `product`, or `commodity`), and a finite explicit visibility in `[0,1]`, with one at the visible-to-user top and zero at the invisible bottom. One to twelve unique straight muted dependencies state value-chain dependence without arrowheads or runtime meaning, and every component is incident. Optional movement names only the strictly adjacent band to the right, is limited to two components, and renders as a short dashed accent arrow paired with the moving dot. The measured 960px plot has four equal bands, dashed separators, uppercase mono labels, stacked visibility endpoint phrases, `r=6` dots, and labels 12px above. All meaningful text uses a 12px logical floor and the shared 16/14 display scale, producing a 1280px standard SVG. Positions remain authored and never move; protected dot, third-party label, dependency, movement, axis, boundary, or legend interference raises an actionable `LayoutError`. Free x/y, scores, numeric ticks, inferred positions/dependencies, focal fields, link or movement labels, icons, custom colors, and architecture/runtime semantics are deferred. The fixed visible and accessible caption states that band and visibility positions are qualitative author judgments, not calculated scores. This remains bounded partial parity against Cathryn Lavery’s pinned Wardley reference.

All types share a left-aligned title, an understated divider, and margins around the scene. The renderer sizes each SVG from its content rather than forcing every diagram into the same aspect ratio.

**The Readable Overflow Rule.** SVG viewBox units remain the layout contract, while each diagram type receives a fixed physical display scale derived from its smallest meaningful text role. Shared 14px body text renders at about 16px; the smallest meaningful type-specific metadata renders at least 12px. Fishbone, data flow, high level, DP integration, process/swimlane, and story map/journey promote those logical roles to 12px and measure local cards, masks, labels, and lanes around them, so the whole scene settles at the shared 16/14 scale. Standard representatives remain at or below 1440 CSS px; deliberately dense supported fixtures remain at or below 1800px. Scaling the complete SVG preserves measured geometry, title hierarchy, and fallback-font clearances. The optional StreamWeaver component provides horizontal scrolling in a focusable, named region when space is narrower. Standalone SVG/HTML can overflow the viewport; other embedding hosts must provide their own scroll container.

**The Honest Bounds Rule.** The API caps diagrams at 32 nodes or events, 64 edges, three groups, and 300 characters per text value. These limits do not guarantee every graph will fit: routing or label placement can raise actionable errors asking the author to shorten labels or split the diagram.

The shared graph router avoids node obstacles, reserves connection portals and earlier bends, and keeps parallel segments at least (12px) apart instead of sharing corridors. Connector label masks stay (8px) clear of polylines; crossings reserve a (16px) halo for an (8px) hop and an additional (8px) label gap. The later-rendered connector receives a circular hop at a crossing; dashed connectors render after solid ones. A crossing too close to a bend or another hop raises `LayoutError`, as does a graph without a faithful route or label position. Crossing-free routing is not guaranteed. Check layout geometry and real rendered pages at desktop and narrow widths; valid SVG or a successful canvas push alone is insufficient.

## Elevation & Depth

The surface is flat. Tonal store fills, emphasis tints, outlines, and dashed group boundaries distinguish meaning. Rendered diagrams have no shadows, gradients, background images, or animations. The user-approved printing-press image in the README is a separate editorial asset, not a diagram background or a renderer dependency. Connection paths render behind nodes; connector label paper masks keep their text legible.

## Shapes

Ordinary nodes retain rectangular label space with gently rounded corners. Flowchart decisions are real diamonds with text measured inside the shape and connections attached to its boundaries. Flowchart start and finish nodes have centered text and roundrect corners; a merge is an unlabeled ink dot with radius (4px), no detail text, and no emphasis. Outside flowcharts, a decision retains the small diamond indicator inside a rectangular node. External nodes use dashed boundaries, and stores use the secondary fill.

**The Typed Flow Rule.** Label every flowchart decision exit and use at most three exits. Start nodes cannot have incoming connections; finish nodes cannot have outgoing connections. Merge junctions require two or three inputs and exactly one output. In eligible simple, ungrouped downward flows, recognized Yes/No branches place Yes to the right and No below; complex graphs retain the bounded layered layout.

Groups have larger rounded corners and dashed boundaries. Boundaries and lifelines use a (4px / 4px) dash pattern. Rules and node outlines are (1px); muted connector strokes are (1.2px), ending in filled arrowheads for graph diagrams. Sequence calls use solid lines and filled heads; returns use dashed lines and filled heads; asynchronous notifications use dashed lines and open heads. Success messages use solid accent lines and filled accent heads, limited to two headline successes. The legacy `dashed: true` message form maps to a return. Orthogonal route turns soften with a radius up to (8px), reduced on short segments.

Sequence activation bars are (8px) wide, with each nested level shifted (4px) right. They use secondary fill and muted outlines (0.8px). Frames use softly rounded corners, secondary fill at (30%) opacity, and rule outlines (0.8px). An operator tab (56 × 24px) names ALT, OPT, or LOOP; guarded regions use bracketed monospace labels, and alternative regions have a dashed separator.

## Components

The bounded high-level slice adds a dedicated source/component phase model with forward unlabeled data links, one explicit focal component, orchestration targets, and automatically paired concern crosscuts. Source types remain semantic accessible text while icons are deferred.

The library's components are diagrams and SVG primitives, not application controls. The sidecar and executable gallery cover all thirty-nine implemented types across the four presets and light/dark themes, including Cartesian quantitative scales, radial radius scales, UML natural compartments, exact marker ownership, endpoint multiplicities, all six legend kinds, and accessible descriptions. Polar uses equal authored angles and linear value rays with constant endpoint markers; zero retains its spoke and labels but draws no ray or marker. Radar places every vertex on one declared common linear scale and draws entity polygons as outlines only. Visible and accessible captions state that radius encodes value and enclosed area has no quantitative meaning. This completes named coverage while remaining bounded partial parity against the 39-type upstream inventory; full upstream variant parity is not claimed. Static Read surfaces have no custom hover or active state; the StreamWeaver scroll region uses browser focus behavior.

The node, store, emphasized node, group boundary, connector label, participant lifeline, timeline entry, org owner, state box, transition label, rule card, dependency box, external metadata, leaf treatment, and fan-in badge share the same palette and typography. Org invocation and unavailable status, plus state transition labels, use the monospace/ui-monospace role; dependency version/registry metadata and cycle labels use the monospace/ui-monospace role; names and scopes remain sans-serif. The StreamWeaver wrapper adds the component margin and scroll behavior without requiring live backend interaction to display the diagram.

**The Described Structure Rule.** Each SVG has an accessible title and description. Generated descriptions include nodes, relationships, and group membership, or timeline events. Flowchart descriptions explicitly name start, finish, decision, and merge roles, including merge identities that have no visible text. Timeline descriptions distinguish elapsed-day spacing from ordered milestones and follow the rendered event order. Sequence descriptions preserve message kinds, activation scopes, frame operators, and guards rather than flattening control flow into a message list; JSON steps preserve the same structure. Org descriptions preserve owner names, invocation routes, scopes, unavailable state, reporting connections, and escalation/approval rules. State descriptions preserve state names, entry/final markers, transition events, guards, actions, self-loops, and feedback transitions. Dependency descriptions preserve dependent→requirement wording, external version/registry metadata, computed fan-in, and the marked cycle. An author-supplied description replaces the generated description and should preserve the information needed to understand the diagram.

The executable gallery covers all thirty-nine named implemented diagram types. UML-class generated descriptions preserve class kind and order, literal members, focal identity, relationship kinds, owners, and endpoint multiplicities. A supplied `description:` replaces generated UML prose.

## Do's and Don'ts

High-level generated descriptions include phase order, source type, component role, focal identity, effective `secondary`/`primary`/`trigger` data-path styles, orchestration targets, and paired concerns. A supplied `description:` replaces the generated description.

### Do:
- Do preserve the approved editorial direction and upstream attribution.
- Do write compact semantic labels and let the renderer own geometry.
- Do verify geometry and real desktop and narrow browser output with local font fallbacks.
- Do split diagrams when bounded routing or label placement cannot represent them faithfully.
- Do run `bundle exec rspec` when changing renderer or layout behavior; executable examples are contracts.

### Don't:
- Don't exceed two focal nodes or events.
- Don't shrink diagram text below the renderer's type-aware readability scale to fit a narrow viewport.
- Don't add font downloads, background imagery, decorative gradients, animation, or external SVG dependencies to rendered diagrams.
- Don't claim crossing-free routing, all 39 upstream shapes, or full upstream visual parity.
- Don't move calendar markers away from their exact dates to resolve label density.
