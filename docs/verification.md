# Verification — 2026-09-08

## 0.30.0 radial quantitative gate — 2026-09-13

- Focused model, strict JSON, exact radius, zero, outline-only SVG, CLI, package, and StreamWeaver checks run before the browser gate.
- The browser acceptance sheet covers polar minimal/zero/focal and eight-category Unicode dark/full states; radar 2-entity centre/outer and 5-entity × 5-criterion light/dark stress states, visible captions, colour-independent patterns, narrow named scrolling, and non-crashing rejection summaries.
- After focused checker and browser clearance, run the full suite once, build exact `tmp/slim_graph_r-0.30.0.gem`, install normally through active RVM, and verify from `/tmp` under `LC_ALL=C` with only Bundler/source variables unset.

## 0.29.0 area and conservation gate — 2026-09-13

- Focused model, strict JSON, geometry, metadata, and package-manifest specs cover exact treemap share/coverage, zero absence, tiny external legends, exact three-stage Sankey conservation, one scale, fractional ribbons, disjoint offsets, and subpixel rejection.
- Browser acceptance uses `tmp/area_conservation_acceptance.rb` on the existing `slim-graph-plan` canvas: five stacked light/dark/Unicode charts, ordinary and tiny treemaps, explicit Waste, 15-ribbon ordering stress, fractional ribbons, and documented nonexecuting rejection cases.
- After focused checker and browser gates, run the full suite once, build exact `tmp/slim_graph_r-0.29.0.gem`, install normally through active RVM, and verify from `/tmp` under `LC_ALL=C` with only Bundler/source variables unset.

## 0.28.0 Cartesian quantitative gate — 2026-09-09

- Focused RSpec covers immutable BigDecimal records, strict Ruby numeric and JSON validation, plain half-even rounding, signed and zero geometry, deterministic auto reference domains, elapsed-day and ordinal line spacing, explicit gaps, required scatter scales, accessibility, and actionable measured-layout failures.
- The existing `slim-graph-plan` canvas covers signed plus zero bars, an all-zero reference domain, irregular elapsed-day line spacing with a gap, an ordinal warning, positive and negative constant line reference domains, signed and zero scatter points with annotations, light/dark skins, and local Unicode/fallback fonts.
- Inspect actual SVG bounding boxes and descriptions at desktop and inside a named narrow scrolling region. Meaningful logical text remains 14px for body labels and at least 12px for metadata, displayed at the shared 1.143 scale. Standard intrinsic width is 1000 logical pixels; earned stress remains at or below 1800.
- After focused checker and browser gates, run the full RSpec suite once, build exact `tmp/slim_graph_r-0.28.0.gem`, install it normally through active RVM, and verify from `/tmp` under `LC_ALL=C` with only Bundler/source variables unset. Verify Ruby API, strict JSON, CLI/version/XML, paired identity, quantitative metadata, and packaged documentation/example bytes.

## 0.27.0 Wardley map — 2026-09-12

- Focused RSpec covers immutable records, strict Ruby/JSON identity, enum/range/connectivity/movement validation, exact linear visibility mapping, 12px logical text roles, 1280px standard width, all styles/themes, accessible descriptions, strict JSON allowlists, and failure without dot movement.
- The standard, dark/style, dense-link, Unicode/fallback, one/two-movement, and narrow-scroll fixtures are collected on the existing `slim-graph-plan` StreamWeaver canvas for desktop and narrow browser inspection.
- Release status remains partial: 32 partial, 7 missing, and 0 verified against the pinned upstream variants.

## 0.26.1 size normalization — 2026-09-11

- Focused RSpec contracts cover exact physical scale and standard width for fishbone, data flow, high level, DP integration, process, swimlane, story map, and journey, plus fishbone’s compact standard and three-lower geometry.
- Standard physical widths are 1418, 1166, 1143, 1418, 910, 695, 997, and 1248px respectively. The supported three-lower fishbone is 1600px. Every affected family uses the shared 1.143 display scale.
- Logical body labels are at least 14px and meaningful metadata is at least 12px. Layout measurement uses the same promoted sizes for cards, lanes, tracked headings, protocol masks, legends, and Unicode/fallback-font clearances.
- Semantic topology, routes, source order, accessible descriptions, palettes, intrinsic `min-width`, and the optional focusable StreamWeaver scrolling region remain unchanged. Coverage remains 31 partial, 8 missing, and 0 fully verified.

- `bundle exec rspec`: 21 examples, 0 failures (Ruby 3.3.5, StreamWeaver 0.3.0).
- Specs exercise elegant DSL examples, invalid inputs, Unicode and safe XML, deterministic explicit IDs, unique default IDs, branching/merging/cycles/disconnected graphs, distinct repeated-edge ports, node collision avoidance, labels, grouping, org charts, sequence self-messages, timelines, and StreamWeaver integration.
- StreamWeaver paths exercised: component rendering, in-memory live bridge push and persisted DSL, saved-document reader, and HTML exporter.
- Actual canvas push succeeded, and a GET of its browser page returned HTTP 200. The final saved source is examples/gallery.rb, which requires the installed extension rather than embedding a development filesystem path.
- Browser gallery inspected at desktop and narrow widths. At 390px, body scroll width remained within the viewport; diagram overflow stayed inside its focusable scroll regions. Each SVG retained its type-aware readable physical scale: ordinary text stayed near 16px and the smallest meaningful metadata stayed at least 12px. Horizontal scrolling is intentional and does not reflow graph topology.
- Independent finish review requested one correction: group membership in accessible descriptions. Corrected, covered by RSpec, and scored resolved by the reviewer. The review was bounded, not exhaustive dense-graph or assistive-technology testing.
- Design detector found reference-font warnings only; these fonts are an approved requirement, with local fallbacks documented.
- Gem built and installed locally. A separate process loaded the installed gem and successfully exported a StreamWeaver diagram.
- artifacts/gallery.html is the portable HTML export. The diagram SVGs have no runtime asset dependencies; the StreamWeaver shell may still request its own assets.

No StreamWeaver source changes or canvas-server repair were made as part of this build. Its existing public component interface supports the optional extension.

## 0.2.0 foundation follow-up

- Full local suite: 35 RSpec examples, 0 failures.
- Core-only bundle: 30 RSpec examples, 0 failures, excluding the optional integration directory.
- StreamWeaver 0.3.0 selected through the release integration bundle: 5 RSpec examples, 0 failures. The main local bundle also passed against installed 0.3.1.
- `ruby bin/check-package`: successful build/install into temporary GEM_HOME/GEM_PATH; no StreamWeaver installed; all five packaged standalone Ruby examples plus JSON and HTML output render. Test environment forces LC_ALL=C and clears Bundler/RUBYOPT/RUBYLIB.
- CLI subprocess specs cover actual stdout, JSON stdin, trusted Ruby, syntax/usage/UTF-8 errors, presentation overrides, safe replacement and no truncation on failed renders.
- Built-in palette specs check text contrast against paper/secondary/tint; the original editorial accent needed small light/dark corrections.
- Actual browser checked all eight style/mode combinations and heading fonts. Ruby light was rechecked directly in the viewport after a full-page screenshot showed a compositor blank region; its contents render correctly. At width390, page scrollWidth375 and diagram wrappers contained the horizontal overflow. Temporary viewport override reset.
- Independent finish reviewer disposition: ship at the bounded foundation scope. Its nonblocking package-link observation was resolved by including the README's hero and roadmap targets in the gem.
- Hosted GitHub Actions have been configured for Ruby3.1–3.4 core jobs and separate StreamWeaver release/git integration jobs. These hosted jobs have not been executed here.
- Installed local CLI reports `slimgraph 0.2.0`. Artifacts include `artifacts/styles.html`, refreshed `artifacts/gallery.html`, and `examples/rendered/architecture.svg` used by the README.
- Example locations moved to `examples/standalone/` and `examples/stream_weaver/`; old mentions above describe the original 0.1 verification.
- Final plain-shell CLI stdout was parsed as XML successfully. An initial local RVM rubygems-bundler auto-setup emitted a dependency-resolution line before the CLI while the bundle needed refreshing; `bundle install --local` refreshed it. Both `bundle exec slimgraph ...` and the plain installed `slimgraph ...` then produced valid XML. No global RVM configuration was changed.

## 0.3.0 flowchart and connector slice — 2026-09-09

- Full suite: 46 RSpec examples, 0 failures. The focused flowchart regression suite also passed after adding the final merge-port approach assertion.
- Published StreamWeaver 0.3.0 integration bundle: 5 examples, 0 failures.
- Isolated gem build/install check passed, including the new full flowchart example, JSON, UTF-8 content under LC_ALL=C, and no StreamWeaver dependency.
- Flowchart checks cover real diamond/terminator/dot output, long text fitting inside diamonds, boundary ports, conventional Yes/No placement, three guarded exits, two/three-input junctions, topology errors and JSON kinds.
- Connector checks cover separate parallel paths, frame bounds, unrelated-node avoidance, label clearance, a crossing halo for the hop itself, future-port reservations and rejection of unrepresentable bend crossings. An intentionally crossed graph exercises actual automatic routing and a rendered arc.
- The browser gallery was inspected in light and dark mode at desktop width. At390px, page width375px stayed within the viewport and each diagram scrolled inside its245px region; temporary viewport override was reset.
- Independent bounded finish review approved the slice and verified the targeted portal/hop-clearance correction. DESIGN.md and its sidecar were refreshed, preserving explicit remaining parity gaps.
- Installed local version: SlimGraphR0.3.0. Updated examples/rendered/flowchart.svg and artifacts/flowcharts.html provide reusable outputs. No complete upstream variant is marked verified solely by this slice.


## 0.5.0 timeline slice — 2026-09-09

The date-fidelity claims in this section were incomplete: 0.5.0's minimum marker spacing distorted clustered or out-of-order dates. The 0.5.1 regression evidence below supersedes those claims.

- Full suite: 63 RSpec examples, 0 failures. Timeline tests cover date parsing, elapsed spacing, axis ticks, ordered mode, auto selection and explicit date-mode errors.
- Date-scaled timeline rendered via installed 0.5.0 CLI and StreamWeaver canvas after rebuilding/restarting the bridge to remove the stale 0.4.0 gem. Canvas page returned HTTP200.
- Browser review at desktop width showed three dates on a horizontal axis with alternating above/below event labels; the widened 1140px scene keeps the rightmost detail clear.
- Existing non-date gallery milestones were migrated to parseable dates. Ordered mode remains documented for caption-like dates.
- Isolated package and StreamWeaver release integration checks remain green from the preceding foundation; local installed CLI reports 0.5.0.

## 0.5.1 timeline fidelity correction — 2026-09-09

- Full suite: 74 RSpec examples, 0 failures. StreamWeaver 0.3.0 release integration bundle: 7 examples, 0 failures.
- Regression evidence covers exact elapsed-day ratios, stable chronological sorting, same-date grouping, single-date domains, strict Gregorian parsing, leap days, long callouts, readable ticks, dense-input errors, scale validation and CLI overrides.
- Canvas, reader and export produce identical marker dates/coordinates/counts. The isolated package check renders the timeline Ruby/JSON examples with StreamWeaver absent and LC_ALL=C.
- Desktop browser review confirmed light/dark same-day grouping and an explicit ordered example. At 390px, page width375 remained within the viewport; diagrams scrolled inside their regions. Marker coordinates were inspected directly, including January16 at313.3333333333333 on the January1–April1 axis. Temporary viewport override reset.
- Independent bounded review found no material defect, including direct checks of Gregorian dates around1582, four-digit year extremes, duplicate leap-day events and invalid1900-02-29.
- No shared canvas bridge restart was needed; only this library's development code and task canvases were refreshed. DESIGN.md and its sidecar now describe the corrected behavior.
- Full upstream reference-variant parity remains partial. Broken-axis timelines and time-of-day axes are not implemented; indistinguishable dates fail rather than being displaced.
