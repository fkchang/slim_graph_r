# Pinned upstream variant-gap audit

This is the human source of truth for SlimGraphR 0.30.0 against Diagram Design revision `dcd9317ed9ec7477b20005544f36e3313664d815`. It audits presentation cases and type-specific variants after all 39 named diagram types reached bounded partial implementations. It does not verify parity: the current result is **39 partial, 0 missing types, and 0 verified types**.

## Method and counting rules

The audit read all 39 pinned `tmp/upstream-types/type-*.md` contracts, mechanically inventoried 445 headings, then reconciled that inventory with five semantic audits covering foundation, hierarchy, workflows, strategy, and quantitative types. Local evidence includes the public guides, executable examples, model/layout/rendering source, and focused RSpec. Those artifacts show that a bounded local case can be expressed; they do not prove that it matches an upstream render.

Every type has three global presentation cases: `minimal-light`, `minimal-dark`, and `full-editorial`. That is **39 × 3 = 117 baseline cases**. Baseline names are counted once per type and are never mixed into the type-specific variant count. `style: :editorial` and `theme: :dark` are implementation capabilities, not proof of the corresponding upstream asset.

The audit classifications are:

- **supported-unverified** — the bounded local model and renderer appear able to express the case, with cited local evidence, but no exact pinned fixture has passed the browser and semantic gate.
- **deliberate-different** — the local contract explicitly chooses a different, bounded meaning or presentation. The difference still needs a pinned comparison before any surrounding case can be verified.
- **missing** — the named case cannot be expressed faithfully by the current public contract.

Priorities run from P0 (parity gate or high semantic value) through P2 (bounded extension or polish). Risk is the consequence of encoding, layout, or interpretation drift: H high, M medium, and L low.

An explicit upstream heading or named example is a candidate only when it denotes a distinct reusable input or presentation contract. Mechanical headings such as `Variants`, `Dumbbell element pattern`, `Dumbbell honesty rules`, `What makes it the consultant variant`, and `Anti-patterns (variant-specific)` describe or subdivide another candidate; they are not extra variants. The Process “extended variant” worked example and IT state zone-width prose are preserved as test cases, not counted as distinct contract variants. Example filenames for slopegraph, ridgeline, bump, bubble, beeswarm, consultant quadrant, vertical High-Level, and datalake point back to their named variants rather than creating duplicates.

## Baseline readiness: 117 cases

The aggregate baseline disposition is **62 supported-unverified, 7 deliberate-different, and 48 missing**. Every supported-unverified case still requires an exact fixture plus a real browser geometry, typography, contrast, accessibility-description, and semantic review before it can move to `verified_variants`.

| Type | minimal-light | minimal-dark | full-editorial | Pinned anchor | Exact local evidence | Principal prerequisite / user value / risk / priority |
| --- | --- | --- | --- | --- | --- | --- |
| Architecture | supported-unverified | supported-unverified | supported-unverified | `type-architecture.md:75-78` | `examples/standalone/architecture.rb:3-8`; `spec/layout_spec.rb:3-15,66-81`; `spec/flowchart_spec.rb:85-146` | Exact three-case fixtures; trustworthy system topology; route/zone drift M, P0 |
| Flowchart | supported-unverified | supported-unverified | supported-unverified | `type-flowchart.md:20-23` | `examples/standalone/flowchart.rb:3-16`; `spec/flowchart_spec.rb:21-69,103-165` | Exact three-case fixtures; readable decisions and merges; geometry M, P0 |
| Sequence | supported-unverified | supported-unverified | supported-unverified | `type-sequence.md:124-130` | `examples/standalone/sequence.rb:3-13`; `examples/standalone/sequence_frames.rb:3-26`; `spec/sequence_spec.rb:21-95` | Exact three-case fixtures and frame review; protocol ownership; marker/scope M, P0 |
| Timeline | supported-unverified | supported-unverified | supported-unverified | `type-timeline.md:17-20` | `examples/standalone/timeline.rb:3-9`; `spec/layout_spec.rb:113-126`; `spec/timeline_spec.rb:29-39` | Exact three-case fixtures; honest elapsed history; temporal distortion H, P0 |
| Org chart | missing | missing | supported-unverified | `type-org-chart.md:41-44` | `examples/parity/org_chart_agent_team.rb`; `spec/org_chart_spec.rb:17-51,104-146` | Browser gate for exact editorial fixture; ownership routing; hierarchy M, P1 |
| State machine | missing | missing | supported-unverified | `type-state.md:18-21` | `examples/standalone/state_machine.rb:3-13`; `spec/state_spec.rb:297-364` | Exact fixtures; lifecycle transitions; cycle/label geometry H, P0 |
| Dependency graph | missing | missing | supported-unverified | `type-dependency.md:40-44` | `examples/parity/dependency_typescript_monorepo.rb`; `spec/dependency_spec.rb:36-87,175-260` | Exact editorial fixture renders all 9 nodes and 12 relationships; browser gate pending; routing H, P0 |
| Deployment | supported-unverified | supported-unverified | supported-unverified | `type-deployment.md:41-45` | `examples/standalone/deployment.rb:4-21`; `spec/deployment_spec.rb:99-112`; `docs/deployments.md:50-108` | Exact fixtures; physical/version placement; containment H, P0 |
| IT current-state | missing | missing | deliberate-different | `type-it-state.md:394-440` | `docs/it-current-state.md:100-118`; `docs/roadmap/parity-and-identity.md:42-46` | Browser light/dark fixtures; modernization “before” story; vertical/editorial gap H, P1 |
| High-Level | missing | missing | deliberate-different | `type-high-level.md:451-461` | `spec/high_level_spec.rb:267-330,394-400`; `docs/high-level.md:118-126` | Browser fixtures and orientation decision; data-stack story; concern topology H, P0 |
| Tree | missing | missing | deliberate-different | `type-tree.md:21-24` | `spec/tree_spec.rb:121-199`; `docs/trees.md:107-111` | Browser fixtures; hierarchy decomposition; buses/labels M, P1 |
| Nested containment | missing | missing | deliberate-different | `type-nested.md:19-22` | `spec/nested_spec.rb:112-114`; `docs/nested-containment.md:94-100` | Browser fixtures; scope/blast radius; callout fit M, P1 |
| Layer stack | missing | missing | deliberate-different | `type-layers.md:23-26` | `spec/layers_spec.rb:108-129`; `docs/layer-stacks.md:84-90` | Browser fixtures; ordered abstraction; annotation fit M, P1 |
| Pyramid / Funnel | missing | missing | deliberate-different | `type-pyramid.md:30-33` | `spec/pyramid_spec.rb:67-87,149-158`; `docs/pyramids.md:83-110` | Browser fixtures; honest hierarchy/quantity; width semantics H, P0 |
| Medallion | missing | missing | deliberate-different | `type-medallion.md:346-350` | `spec/medallion_spec.rb:6-18,47-77,172-180`; `docs/medallions.md:93-126` | Browser fixtures and style-field decision; data promotion; precedence H, P0 |
| Swimlane | missing | missing | supported-unverified | `type-swimlane.md:17-20` | `examples/parity/swimlane_release_workflow.rb`; `spec/workflow_spec.rb:207-267` | Exact editorial fixture renders all 7 activities and 6 handoffs; browser gate pending; lane geometry H, P1 |
| Process | supported-unverified | supported-unverified | supported-unverified | `type-process.md:488-492` | `docs/processes.md:8-59,134-163`; `spec/workflow_spec.rb:119-213,243-247` | Canonical payload/connector fixture and full frame; process audit; routes H, P1 |
| Gantt | supported-unverified | supported-unverified | supported-unverified | `type-gantt.md:41-45` | `docs/gantt.md:129-170,191-202`; `spec/planning_boards_spec.rb:97-98,231-235` | Exact date fixtures and full frame; schedule truth; calendar labels H, P1 |
| Kanban | supported-unverified | supported-unverified | supported-unverified | `type-kanban.md:45-49` | `docs/kanban.md:141-180`; `spec/planning_boards_spec.rb:231-235` | Exact state/WIP fixtures and full frame; work census; density M, P1 |
| User journey | missing | missing | supported-unverified | `type-journey.md:49-53` | `docs/journeys.md:104-124`; `spec/journey_spec.rb:72-101`; `spec/integration/journey_spec.rb:11-21` | Exact ordinal-sentiment fixtures and full frame; intervention point; false quantitation H, P1 |
| User story map | supported-unverified | supported-unverified | supported-unverified | `type-story-map.md:42-46` | `docs/story-maps.md:113-129`; `spec/journey_spec.rb:104-129`; `spec/integration/journey_spec.rb:11-21` | Exact cut/gap fixtures and full frame; release scope; release semantics M, P1 |
| Data flow | missing | missing | supported-unverified | `type-data-flow.md:367-371` | `docs/data-flows.md:136-164`; `spec/data_flow_spec.rb:182-224,294-304` | Canonical 4×5 fixture and full frame; pipeline ownership; focal/routes H, P1 |
| DP integration | missing | missing | supported-unverified | `type-dp-integration.md:403-407` | `docs/platform-integrations.md:193-232`; `spec/dp_integration_spec.rb:174-226`; `spec/integration/dp_integration_spec.rb:11-22` | Canonical trust fixture and full frame/icon decision; integration topology; trust scope H, P1 |
| DP security matrix | supported-unverified | supported-unverified | supported-unverified | `type-dp-security-matrix.md:292-296` | `docs/access-matrices.md:149-178`; `spec/dp_security_matrix_spec.rb:149-190`; `spec/integration/dp_security_matrix_spec.rb:11-23` | Exact level mapping and full frame; access review; permission meaning H, P1 |
| ER / Data model | missing | missing | supported-unverified | `type-er.md:22-25` | `examples/parity/er_publishing_domain.rb`; `spec/er_spec.rb:151-215` | Browser gate for exact editorial fixture; conceptual cardinality; endpoint geometry H, P0 |
| Database schema | missing | missing | supported-unverified | `type-db-schema.md:44-47` | `examples/parity/db_schema_checkout.rb`; `spec/db_schema_spec.rb:73-106,134-233` | Browser gate for exact editorial fixture; physical constraints/FKs; route actions H, P0 |
| UML class | missing | missing | supported-unverified | `type-uml-class.md:61-64` | `examples/standalone/uml_class.rb:5-18`; `spec/uml_class_spec.rb:43-113,150-191` | Exact three-case fixtures; relation ownership; markers H, P0 |
| Quadrant | missing | missing | supported-unverified | `type-quadrant.md:18-22` | `docs/quadrants.md:59-69`; `spec/quadrant_spec.rb:100-145` | Exact three-case fixtures; qualitative position; label movement H, P0 |
| Venn | missing | missing | supported-unverified | `type-venn.md:23-26` | `docs/venn.md:64-88`; `spec/venn_spec.rb:40-60,81-131` | Exact two/three-set fixtures; overlap topology; labels M, P0 |
| Loop | missing | missing | supported-unverified | `type-loop.md:219-223` | `examples/standalone/loop.rb:4-14`; `spec/loop_spec.rb:36-116` | Exact six-station fixtures; operating feedback; arc/spoke meaning H, P0 |
| Fishbone | missing | missing | supported-unverified | `type-fishbone.md:71-74` | `docs/fishbones.md:84-95`; `spec/fishbone_spec.rb:7-27,37-104` | Exact five-bone fixtures; investigation structure; causal overclaim H, P0 |
| Wardley | missing | missing | supported-unverified | `type-wardley.md:35-38` | `examples/parity/wardley_ai_value_chain.rb`; `spec/wardley_spec.rb:42-114` | Exact editorial fixture renders all 8 components and 7 crossed dependencies with bridges; browser gate pending; qualitative evolution H, P0 |
| Bar / Column | supported-unverified | supported-unverified | supported-unverified | `type-bar.md:102-106` | `docs/bar-charts.md:3-16`; `spec/quantitative_spec.rb:11-31,129-176` | Exact light/dark fixtures and full frame; honest comparison; zero/domain H, P0 |
| Line | supported-unverified | supported-unverified | supported-unverified | `type-line.md:249-262` | `docs/line-charts.md:3-18`; `spec/quantitative_spec.rb:74-114,180-199` | Exact light/dark fixtures and full frame; trend over time/order; domain/gaps H, P0 |
| Scatter | missing | missing | supported-unverified | `type-scatter.md:187-197` | `docs/scatter-plots.md:3-16`; `spec/quantitative_spec.rb:116-138,202-217` | Exact light/dark fixtures and full frame; two-variable relation; scales H, P0 |
| Radar | supported-unverified | supported-unverified | supported-unverified | `type-radar.md:76-80` | `docs/radar-charts.md:3-20`; `spec/radial_spec.rb:55-101` | Exact light/dark fixtures and full frame; multi-criterion profile; area implication H, P0 |
| Polar | supported-unverified | supported-unverified | supported-unverified | `type-polar.md:132-136` | `docs/polar-charts.md:3-19`; `spec/radial_spec.rb:29-53,76-101` | Exact light/dark fixtures and full frame; ordered radial values; radius/zero H, P0 |
| Treemap | supported-unverified | supported-unverified | supported-unverified | `type-treemap.md:62-66` | `docs/treemaps.md:3-17`; `spec/area_conservation_spec.rb:11-75` | Exact light/dark fixtures and full frame; part-to-whole; area truth H, P0 |
| Sankey | missing | missing | supported-unverified | `type-sankey.md:68-72` | `docs/sankeys.md:3-23`; `spec/area_conservation_spec.rb:77-178` | Exact light/dark fixtures and full frame; conserved flow; scale/loss H, P0 |

## Named type-specific variants and candidates

These 17 canonical candidates reconcile all distinct names found by the mechanical inventory and semantic audits. Their descriptive subheadings and example filenames are aliases, not extra counts.

| Type / variant | Pinned source anchor | Classification | Exact local evidence and gap | Prerequisite / user value / risk / priority |
| --- | --- | --- | --- | --- |
| Sequence — OAuth bearer call with `alt` refresh | `type-sequence.md:124-130` | supported-unverified | `docs/sequence.md:48-70`; `lib/slim_graph_r/sequence_definition.rb:30-63`; no OAuth fixture | Exact auth fixture; familiar failure/retry story; guard scope M, P1 |
| IT current-state — vertical orientation | `type-it-state.md:11-18,84-123` | missing | `docs/it-current-state.md:113-118` explicitly limits layout to horizontal | Second measured geometry/router; portrait modernization maps; routing H, P1 |
| High-Level — right-strip vertical chevrons | `type-high-level.md:211-239,370-392,456` | supported-unverified | `spec/high_level_spec.rb:267-330`; local crosscuts auto-pair rather than accepting manual vertical input | Exact vertical fixture and pairing decision; concern ownership; pairing H, P0 |
| High-Level — unclustered datalake | `type-high-level.md:451-461` | missing | `docs/high-level.md:124-126` excludes unclustered variants | Cluster-optional layout contract; lake topology; containment M, P1 |
| Pyramid — funnel orientation | `type-pyramid.md:5-22` | supported-unverified | `spec/pyramid_spec.rb:67-87,149-158`; `docs/pyramids.md:83-110` | Exact funnel fixture; conversion/attrition; width semantics H, P0 |
| Medallion — `outer/default/focal/cold` style taxonomy | `type-medallion.md:142-218,284-315` | deliberate-different | `docs/medallions.md:93-126`; local semantic concerns and archive/focal precedence replace upstream arbitrary style/color inputs | Decide compatibility mapping; recognizable tier lifecycle; semantic conflict H, P1 |
| Process — extended 6-lane × 11-step worked case | `type-process.md:391-456` | missing | `docs/processes.md:154-160` caps the bounded model and rejects custom colors; this is a stress case, not a separate public variant | Capacity/routing expansion; enterprise workflow; density H, P2 |
| Quadrant — consultant 2×2 scenario matrix | `type-quadrant.md:26-74` | deliberate-different | `docs/quadrants.md:69`; point quadrant exists, scenario cells/descriptions are deferred | Separate scenario contract; strategic futures; type confusion M, P2 |
| Bar — horizontal orientation | `type-bar.md:5-16` | supported-unverified | `lib/slim_graph_r/quantitative.rb:241-244`; `spec/quantitative_spec.rb:172-176` | Exact long-label fixture; readable category comparison; labels M, P1 |
| Bar — grouped | `type-bar.md:39-42` | missing | `lib/slim_graph_r/quantitative.rb:11,134-138` has one value per category | Series model + JSON/geometry rules; within-category comparison; scale H, P1 |
| Bar — stacked | `type-bar.md:39-42` | missing | No segment/stack model or renderer | Segment model + total/zero rules; composition comparison; encoding H, P1 |
| Bar — dumbbell | `type-bar.md:45-100` | missing | One-value category model cannot express paired endpoints | Two-endpoint model and gap semantics; before/after comparison; scale H, P1 |
| Line — slopegraph | `type-line.md:46-142,254` | missing | No two-state endpoint-binding model | Dedicated model and collision-safe endpoint labels; change between two states; rank/scale H, P1 |
| Line — ridgeline | `type-line.md:143-205,257` | missing | No distribution/bin model | Distribution grammar and overlap rules; compare shapes; density H, P2 |
| Line — bump chart | `type-line.md:207-247,260` | missing | No rank-snapshot model | Ordinal rank model; changing rank; crossings H, P1 |
| Scatter — bubble | `type-scatter.md:35-113,192` | missing | `lib/slim_graph_r/quantitative.rb:14,158-163` stores x/y only | Third quantity with square-root radius; three-variable comparison; area encoding H, P1 |
| Scatter — beeswarm | `type-scatter.md:114-185,195` | missing | No one-value swarm/packing model | Deterministic packing and density bounds; distribution without bins; collision H, P1 |

## Deliberate differences that affect parity

These are approved local boundaries evidenced by current public documentation. They are not missing named types and do not become verified through unit tests alone.

| Type(s) | Local decision and evidence | Upstream anchor / consequence |
| --- | --- | --- |
| Architecture / Flowchart / Org chart | Shared semantic palette, generic groups, independently routed hierarchy connectors; `docs/roadmap/parity-and-identity.md:15-21` and its 0.6.0 boundary | `type-architecture.md:52-68`; `type-flowchart.md:15-18`; `type-org-chart.md:7-24`; exact upstream zone/bus/treatment remains unverified |
| Sequence | Excludes `par`, `critical`, `break`, `ref`, create/destroy, and duration bars; `docs/sequence.md:72-74` | `type-sequence.md:85-87`; intentionally bounded UML slice |
| Timeline | `scale: :ordered` is an explicit non-time extension and broken axes/time-of-day/custom domains are excluded; `docs/timeline.md:18-24` | `type-timeline.md:5-15`; caption must prevent elapsed-time inference |
| Dependency | Rejects tree-shaped input and limits marked cycles; `docs/dependencies.md:112-118` | `type-dependency.md:18-38`; routes simpler hierarchy to Tree |
| Hierarchy/platform family | Fixed bounded layouts, semantic palettes, and missing decorative editorial frames are documented in `docs/it-current-state.md:113-118`, `docs/high-level.md:124-126`, `docs/trees.md:107-111`, `docs/nested-containment.md:98-100`, `docs/layer-stacks.md:86-90`, `docs/pyramids.md:92-110`, `docs/medallions.md:95-126` | Corresponding type contracts; preserves faithful fit and semantic color at the cost of presentation compatibility |
| Workflow/platform family | Static authored state, fixed horizontal grids, explicit ordinal/permission/payload semantics, and no inferred analytics; `docs/swimlanes.md:134-138`, `docs/processes.md:154-160`, `docs/kanban.md:159-190`, `docs/journeys.md:112-124`, `docs/story-maps.md:122-129`, `docs/data-flows.md:154-161`, `docs/access-matrices.md:159-178` | Corresponding upstream contracts; avoids inventing state, dates, conversions, or permissions |
| ER / UML / Venn / Loop / Wardley | Routes physical schema and other UML families to dedicated types; caps Venn at three sets; rejects loop branching; keeps Wardley qualitative; respective public guides and `spec/loop_spec.rb:126-137`, `spec/wardley_spec.rb:131-142` | Type contracts’ anti-pattern/boundary sections; preserves type-local meaning |
| Fishbone | Factors are investigated leads; causal/root/focal claims are rejected; `docs/fishbones.md:84-95`; `spec/fishbone_spec.rb:107-125` | `type-fishbone.md:5-12`; avoids presenting correlation as confirmed cause |
| Line / Scatter | No line area fill, inferred trend line, or inferred quadrant dividers; `docs/line-charts.md:16`; `docs/scatter-plots.md:14` | `type-line.md:5-14`; `type-scatter.md:5-13`; avoids undeclared area/fit/median claims |
| Treemap / Sankey | Exact unsnapped area and conserved fractional flow; no invented `Other`; `docs/treemaps.md:3,13`; `docs/sankeys.md:19` | `type-treemap.md:7-22`; `type-sankey.md:20-26`; deliberately favors numeric fidelity over pixel-grid compatibility |
| Radar / Polar | Radar polygons are outline-only with redundant dashes; Polar is radius-only with no wedges/hub; `docs/radar-charts.md:16-20`; `docs/polar-charts.md:15-17` | `type-radar.md:5-15,52-63`; `type-polar.md:38-57`; avoids implying polygon/sector area meaning |

## Sequenced release groups

1. **V0 — audit and fixture gate (P0).** Freeze the 39 exact upstream inputs and local equivalents, retain the pinned revision and source anchors, and record expected semantic assertions. This release changes no `verified_variants` values.
2. **V1 — baseline minimal light/dark (P0).** Keep all 78 unavailable minimal presentations explicit until a real minimal profile exists; then gate geometry, labels, contrast, descriptions, and claims in browser evidence. Start with temporal/quantitative truth and connector-heavy State, Dependency, Deployment, ER/DB/UML, High-Level, Data Flow, and DP Integration.
3. **V2 — editorial baseline (P1).** Review the 26 captured supported-unverified full-editorial cases, retain 7 documented deliberate differences, and implement or explicitly reject the 6 missing frames. A full page is a composition contract, not a style alias.
4. **V3 — high-value semantic variants (P1).** High-Level vertical concerns; Bar grouped/stacked/dumbbell; Line slopegraph/bump; Scatter bubble/beeswarm; exact Pyramid funnel; Medallion style mapping. Each requires dedicated Ruby/JSON input, geometry assertions, and a browser fixture.
5. **V4 — bounded extensions and polish (P2).** High-Level datalake, IT vertical, Process stress case, Quadrant consultant matrix, Line ridgeline, icons, summary cards, decorative gradients/shadows, and other compatibility choices.
6. **V5 — verification promotion.** Promote a case only after the exact fixture, browser review, semantic assertions, accessibility description, package inclusion, and evidence paths are recorded. Recompute totals from the manifest; never infer verification from a shared name or a passing generic theme loop.
