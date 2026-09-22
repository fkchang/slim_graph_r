# Gantt diagrams (0.15 draft)

This is the proposed 0.15 tutorial for `:gantt`, a static calendar plan. The
author supplies phases, tasks, milestones, and reference markers; SlimGraphR
does not fetch, create, update, or infer calendar records. Dates are all-day
ISO Gregorian dates on one elapsed-day scale.

## Standalone Ruby

Declare phases and their tasks in the order you want the rows to appear. A
task belongs to a phase. Milestones and markers are top-level point records.
The sample includes literal Unicode so the same text can be checked through
Ruby and JSON.

Under the shared document contract, `title` defaults to `Diagram`, `style` to
`:editorial`, and `theme` to `:light`; `description` is optional. Styles are
`:editorial`, `:ruby`, `:blueprint`, or `:mono`, and themes are `:light`,
`:dark`, or `:auto`.

Ruby may omit a record's label to use the humanized ID; the JSON branch below
uses explicit labels because strict JSON requires `label` on phases, tasks,
milestones, and markers.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :gantt,
  title: '0.15 plan · 交付计划', style: :editorial, theme: :light do
  phase :foundation, 'Foundation · 基础' do
    task :calendar, 'Calendar scale · 日历',
      start: '2026-01-05', finish: '2026-01-16', focal: true
    task :board, 'Board model · 看板',
      start: '2026-01-12', finish: '2026-01-23'
  end

  milestone :cutover, 'Cutover · 切换', on: '2026-01-23', phase: :foundation
  marker :review, 'Review · 评审', on: '2026-01-16'
end

File.write('plan.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

`phase` cannot nest, and `task` is available only inside a phase. A task's
`focal:` value is a strict boolean and defaults to `false`; at most one task
may be focal. `milestone` and `marker` are top-level point records. A
milestone gets the diamond treatment and may name an existing phase with
`phase:`. A marker gets the muted dashed reference treatment and never accepts
`phase:`. A marker is static author data; it is not the system clock and must
not be described as “today” unless its supplied label says so.

## Equivalent strict JSON

The following JSON is field-for-field equivalent to the Ruby example above.
Use `phases`, `milestones`, and `markers`; do not replace them with generic
`nodes`, `edges`, or `events` collections.

```json
{
  "type": "gantt",
  "title": "0.15 plan · 交付计划",
  "style": "editorial",
  "theme": "light",
  "phases": [
    {
      "id": "foundation",
      "label": "Foundation · 基础",
      "tasks": [
        {"id":"calendar", "label":"Calendar scale · 日历", "start":"2026-01-05", "finish":"2026-01-16", "focal":true},
        {"id":"board", "label":"Board model · 看板", "start":"2026-01-12", "finish":"2026-01-23"}
      ]
    }
  ],
  "milestones": [
    {"id":"cutover", "label":"Cutover · 切换", "on":"2026-01-23", "phase":"foundation"}
  ],
  "markers": [
    {"id":"review", "label":"Review · 评审", "on":"2026-01-16"}
  ]
}
```

The JSON root allowlist is `{type,title,description,style,theme,phases,
milestones,markers}`. A phase accepts `{id,label,tasks}`; a task accepts
`{id,label,start,finish,focal}`; a milestone accepts `{id,label,on,phase}`;
and a marker accepts `{id,label,on}`. `focal` defaults to `false`; milestone
`phase` may be omitted. Optional root fields are `description`, `style`, and
`theme` under the shared document contract. Unknown keys, explicit `null`,
missing required keys, wrong JSON types, duplicate IDs, blank IDs/labels, and
cross-type fields raise `SlimGraphR::Error`.

The strict JSON `phases`, `milestones`, and `markers` arrays are required,
including when an array is empty. The overall document still needs at least
one task or milestone.

Load the same strict document through the library parser:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('plan.json'))
File.write('plan.svg', diagram.to_svg)
diagram
```

JSON is parsed and validated; it is never evaluated as Ruby.

## CLI and optional StreamWeaver

The direct CLI forms are:

```sh
ruby -Ilib exe/slimgraph render plan.rb -o plan.svg
ruby -Ilib exe/slimgraph render plan.json -o plan.html --format html
```

The file extension selects Ruby or JSON. JSON is the stdin default; use
`--input-format ruby` for Ruby source from stdin. `--style` and `--theme`
override presentation without changing the model. Output defaults to SVG;
`--format html` selects the small HTML wrapper. A Ruby input must leave
`diagram` as its final expression, after any `File.write` call.

The planned parity examples cover all four styles (`editorial`, `ruby`,
`blueprint`, and `mono`) and both `light` and `dark` themes.

Calendar direction is fixed; `direction:` is not a Gantt option.

The core renderer depends only on the extracted standard-library `bigdecimal` and `ostruct` gems. StreamWeaver is optional and
is loaded explicitly with `require 'slim_graph_r/stream_weaver'`; it is not
required for standalone Ruby or JSON use.

## Dates, geometry, and meaning

Each task is the half-open interval `[start, finish)`: it includes `start` and
excludes `finish`, and requires `finish > start`. The visible axis caption is
exactly “Task bars include start; finish date is excluded”; generated
accessibility text repeats that convention. Bar endpoints are the exact
scaled positions of the two boundaries. A short task is never widened for
legibility.

All tasks, milestones, and markers require complete valid Gregorian
`YYYY-MM-DD` dates, including leap-day validation. There are no times of day,
partial dates, time zones, durations, implicit finish dates, inclusive ends,
or business-day calculations. Milestones are point dates, not zero-duration
tasks. A plan must contain at least one task or one milestone. A milestone-only
plan is valid; when all of its points share one date, the one-date domain is
centered without inventing an interval.

The planned geometry uses a 180px left label column, a 760px timeline, and
40px task rows with exact-width 24px bars. Phase zones follow phase/task
declaration order. The scale domain is the minimum of task starts, milestone
dates, and marker dates through the maximum of task finishes, milestone dates,
and marker dates. Because finishes are exclusive, the upper endpoint remains
an actual boundary. Sparse calendar ticks retain year context: domain ends use
`YYYY-MM-DD`, and an interior tick includes a year whenever it differs.

Milestones with `phase:` use that phase's marker track aligned to its task
rows. Phase-less milestones and markers use separate global tracks. Milestone
labels stack or route while their points stay fixed. Same-track milestone
diamonds must be at least 12px apart; overlapping diamonds raise
`SlimGraphR::LayoutError`. Same-date or close milestones on separate
phase/task tracks may use distinct clear stacks at the same exact x
coordinate. Markers use their own global track: close marker lines may render
when measured line and label geometry is clear, while overlapping marker lines
raise an actionable layout error.

Text inside a bar appears only when it fits its true width; the left label
remains authoritative. If a true bar is under one CSS pixel, if an overlapping
same-track milestone diamond or marker line cannot be placed, if a measured
label or marker cannot be placed, or if phase/task text cannot fit, the planned
renderer raises `SlimGraphR::LayoutError` with a split-or-narrow-the-range
repair. It does not change dates, widen bars, move points, or introduce an
axis break.

## Limits and deferred semantics

The bounded slice permits 0–4 phases, 0–12 tasks, 1–8 milestones when there
are no tasks (otherwise 0–8 milestones), 0–2 markers, and one focal task.
Task IDs are unique within the task family, and phase/milestone/marker IDs are
unique within their declared family. IDs are nonblank strings and labels are
nonblank UTF-8 strings after the normal `Text.clean` handling. Shared input
limits also apply: text fields are at most 300 characters and a JSON input is
at most 1 MiB.

Dependencies, predecessor types and lags, arrow routing, critical path,
percent complete, baselines, recurring work, collapsing, and auto-generated
phases are deferred. Use the existing `:dependency` diagram for deliberate
relationships. The Gantt model has no automatic “today”.

When `description` is omitted, generated accessibility text reports the title,
phases and declaration-order tasks, the exact date convention, milestones and
markers, focal status, and the effective date domain. An author-supplied
`description` replaces that generated prose. This draft describes the proposed
0.15 contract; it is not an implementation or a test report.

The editorial direction is informed by the pinned [Cathryn Lavery Diagram
Design reference](https://github.com/cathrynlavery/diagram-design/tree/dcd9317ed9ec7477b20005544f36e3313664d815).
SlimGraphR remains an independent renderer; attribution and the upstream MIT
notice stay under `vendor/diagram-design`.

For release verification, run the literal Ruby and JSON examples under both
the checkout and installed gem with an explicit C locale, then inspect the
real standalone HTML page at desktop and narrow widths. A successful SVG
string alone does not establish browser-page correctness.
