# Browser parity harness

`bin/audit-parity-batch architecture` captures a config-selected V0 parity
batch using the original pinned Diagram Design files. It never regenerates or
changes an upstream HTML fixture. `parity-harness-fixtures.json` registers a
local fixture's loader, factory, and explicitly available variants; a batch
selects those entries with `local_fixture` and `local_variant`. An unavailable
variant fails rather than falling back to another profile.

The command verifies each selected upstream asset against the SHA-256 in
`parity-fixtures-v0.json`, then opens both sides as local files in headless
Chromium under a fixed 1440 × 1000 CSS-pixel viewport, device scale factor 1,
`en-US` locale, UTC timezone, reduced motion, and the case's light or dark
colour preference. Upstream Google Fonts stylesheet requests are intercepted
only during capture and fulfilled from pinned local Geist, Geist Mono, and
Instrument Serif WOFF2 assets; the archived upstream HTML bytes are never
rewritten. The harness verifies every asset SHA-256 and every intended face
before capture. Missing or mismatched assets, a failed face check, or an
external-resource failure ends the capture with an actionable error instead of
accepting fallback typography. `bash bin/check-parity-fonts` exercises the
local interception and deliberate hash-mismatch failure path.

Evidence is written under `artifacts/parity/v0/<batch>/` (ignored by Git):

- `upstream.png` is the pinned file rendered unchanged.
- `slimgraphr.png` is the equivalent local Ruby fixture when that presentation
  profile exists.
- `evidence.json` records the verified upstream digest, page and SVG geometry,
  overflow, font status, browser and console errors, and image accessibility
  metadata (role, labelled-by references, SVG title, and description).
- `review.html` puts the browser captures side by side and marks an unavailable
  local presentation explicitly.
- `summary.json` keeps rendered cases `supported-unverified`: render-only work
  is `rendered-awaiting-browser-gate`, and browser captures await human visual
  review. Neither state promotes a record to verified.

The Architecture batch represents the actual pinned content-site semantics:
Reader, Cloudflare Pages, Astro Origin, its MDX bundle and content CMS, with
the five authored routes and labels. Its light and dark minimal cases dispatch
the genuine SlimGraphR `:minimal` profile with the same exact fixture payload.
Render-only availability remains `supported-unverified` until the browser gate
and human visual review complete. The full-editorial case also captures both
sides for review.

The Flowchart, Sequence, and Timeline batches use the same registry contract.
Their minimal and full-editorial fixtures preserve the pinned skill-decision,
cold-cache article request, and product-launch milestone semantics. The eight
minimal render-only cases are `supported-unverified` and await browser capture
and human visual review. The Timeline source names months but not days; its
local fixture uses the first day of each displayed month to express the pinned
month-granular chronology on SlimGraphR's proportional date scale. This input
normalization does not promote visual parity.

The hierarchy batches make source-semantic availability equally explicit.
Deployment has a full-editorial local counterpart for its three zones, five
infrastructure nodes, versioned artifacts, replica count, and four network
paths. Org chart now dispatches its exact full-editorial fixture with visible
setup-gap records. State and Dependency retain their separately recorded
availability boundaries; unavailable cases must not be captured as reduced
substitutes.

The ER and Database Schema batches now dispatch their exact full-editorial
fixtures by stable case ID. ER preserves literal field types and qualifiers plus
aggregate-root and join-table kinds. Database Schema preserves the explicit
`+ 3 more columns` row. Their render-only evidence remains
`rendered-awaiting-browser-gate` until coordinator capture.

Process, Gantt, and Kanban also have full-editorial counterparts: Process
retains all keyed lanes, stages, tools, payloads, and handoffs; Gantt retains
the source's twelve-week phase/task plan through an explicit calendar anchor;
and Kanban retains its WIP breach and four card states. Journey remains
unavailable because the exact pinned `PRICING PAGE IS 3 CLICKS AWAY` pain
marker cannot fit SlimGraphR's fixed five-stage cell. Page framing alone does
not determine availability.

The harness expects Node and a globally installed Playwright browser only as a
development tool. It adds no gem runtime dependency. A next batch needs one
JSON batch file, an exact semantic Ruby fixture, one registry entry, and
focused semantic assertions before it can be captured.

## Coordinator UAT runbook

1. Run `bin/check-parity-fixtures`, `bash bin/check-parity-fonts`, then `bundle exec rspec` from the repository root.
2. Run `bin/audit-parity-batch architecture`, `bin/audit-parity-batch flowchart`, `bin/audit-parity-batch sequence`, `bin/audit-parity-batch timeline`, `bin/audit-parity-batch deployment`, `bin/audit-parity-batch org-chart`, `bin/audit-parity-batch er`, and `bin/audit-parity-batch db-schema` with global Playwright and Chromium installed. Run `state` and `dependency` as well to capture their pinned upstream references and confirm their configured unavailable cases remain unavailable.
3. Open each `artifacts/parity/v0/<batch>/summary.json`; confirm every case has matching expected and observed upstream and contract SHA-256 hashes, no browser, console, or external-resource errors, `fonts.source` is `local-intercept`, all required font checks loaded, and geometry, overflow, and accessibility metadata are recorded.
4. Open every `review.html` in `artifacts/parity/v0/{architecture,flowchart,sequence,timeline,org-chart,state,dependency,deployment,er,db-schema}/`; visually compare each available full-editorial upstream and SlimGraphR capture at 100% scale. Confirm every unavailable case visibly says unavailable and has no SlimGraphR image.
5. Keep `supported-unverified` and `pending-human-visual-review` unless a designated reviewer records a separate visual-parity decision. Capture evidence alone does not authorize promotion.
