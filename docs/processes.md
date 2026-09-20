# Process diagrams

Use `:process` to show a bounded workflow with actor lanes, numbered stages,
one operation in each occupied lane/stage cell, the tool used there, and the
payload entering or leaving it. Use `:swimlane` when actor ownership is the
whole story and tools or payload codes would add noise.

## Standalone Ruby

Process lanes require an explicit uppercase key of one to three characters.
Stage and operation focus are independent: this bounded model requires
exactly one `focal: true` stage and exactly one `focal: true` operation.
Operation labels are the second positional Ruby argument; JSON calls this
field `label`.

The shared document defaults are title `Diagram`, style `:editorial`, and
theme `:light`. Process direction is fixed to `:right`. Omitted labels use the
library's humanized-ID default where that record permits an omitted label.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :process,
  title: 'Survey workflow · pilot', style: :editorial, theme: :light do
  lane :research, 'Research', key: 'R'
  lane :delivery, 'Delivery', key: 'D'
  lane :field, 'Field', key: 'F'

  stage :design, 'Design'
  stage :build, 'Build', focal: true
  stage :review, 'Review'

  operation :draft_survey, 'Draft survey', lane: :research, stage: :design,
            tool: 'CSPro', detail: 'Forms', output: 'TB'
  operation :build_app, 'Build app', lane: :delivery, stage: :build,
            tool: 'RStudio', input: 'TB', output: 'WB', focal: true
  operation :pilot_test, 'Pilot test', lane: :field, stage: :review,
            tool: 'Shiny', input: 'WB'

  handoff :draft_survey, :build_app
  handoff :build_app, :pilot_test
  trigger :pilot_test, :build_app, 'RETEST'
end

File.write('process.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

`tool:` is required. `detail:` is optional. `input:` and `output:` accept only
the payload codes `LS`, `DB`, `TB`, `FL`, and `WB`; omission means unknown, as
does an explicit JSON `null`. The first-stage input and last-stage output are
left unknown in this example. If either boundary payload is supplied, the
model rejects it rather than silently dropping it.

Ordinary handoffs advance through the stages. A trigger is the optional named
backward control edge: `trigger from, to, label`. It is dashed and neutral even
when it touches the focal operation. Focal styling applies to the focal stage
and operation; ordinary handoffs touching the focal operation receive the
accent treatment. Trigger semantics take precedence over focal styling.

## Equivalent strict JSON

JSON mirrors `lanes`, `stages`, `operations`, `handoffs`, and the optional
`trigger` object. Ordinary process handoffs contain only `from` and `to`;
`focal` is a swimlane-only handoff option. Payloads are explicit on operation
records and never inferred from a handoff.

```json
{
  "type": "process",
  "title": "Survey workflow · pilot",
  "style": "editorial",
  "theme": "light",
  "lanes": [
    {"id": "research", "label": "Research", "key": "R"},
    {"id": "delivery", "label": "Delivery", "key": "D"},
    {"id": "field", "label": "Field", "key": "F"}
  ],
  "stages": [
    {"id": "design", "label": "Design"},
    {"id": "build", "label": "Build", "focal": true},
    {"id": "review", "label": "Review"}
  ],
  "operations": [
    {"id": "draft_survey", "label": "Draft survey", "lane": "research", "stage": "design", "tool": "CSPro", "detail": "Forms", "output": "TB"},
    {"id": "build_app", "label": "Build app", "lane": "delivery", "stage": "build", "tool": "RStudio", "input": "TB", "output": "WB", "focal": true},
    {"id": "pilot_test", "label": "Pilot test", "lane": "field", "stage": "review", "tool": "Shiny", "input": "WB"}
  ],
  "handoffs": [
    {"from": "draft_survey", "to": "build_app"},
    {"from": "build_app", "to": "pilot_test"}
  ],
  "trigger": {"from": "pilot_test", "to": "build_app", "label": "RETEST"}
}
```

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('process.json'))
File.write('process.svg', diagram.to_svg)
diagram
```

The parser is strict and never evaluates JSON as Ruby. Unknown, null, wrongly
typed, duplicate, or cross-type fields; duplicate IDs or cells; missing
references; invalid lane keys; non-catalog payload values; boundary payloads;
same-stage or ordinary backward handoffs; and generic `nodes`/`edges` forms
raise `SlimGraphR::Error`. Omitted labels use the library's humanized-ID
default where permitted. `null` is the documented exception for payload
fields; other supplied null fields are invalid.

Process and swimlane layouts are fixed horizontal actor-lane layouts; they do
not accept a direction override.

## CLI and optional StreamWeaver

The CLI supports both input forms:

```sh
slimgraph render process.rb -o process.svg
slimgraph render process.json -o process.html --format html
```

JSON is the stdin default; use `--input-format ruby` for Ruby source from
stdin. `--style` and `--theme` override presentation without changing the
validated model. A Ruby input must leave `diagram` as its final expression.
`--format svg|html` selects the output wrapper explicitly.

StreamWeaver is optional. Load `require 'slim_graph_r/stream_weaver'` and use
the same `diagram :process` block. The core renderer has no runtime dependency
on StreamWeaver.

## Layout, semantics, and limits

The geometry is deterministic: the actor column is 140px wide, each stage is
at least 112px wide, and each lane is 80px high. Operation cards grow from
their measured title, tool, lane key, and payload content. Keys and payloads use
the same 12px mono measurement and 16px chip geometry in cards and legends;
output chips stay anchored to the card's right edge. Stages number contiguously. The process legend
reports numbered steps and focal step, used payload codes, and effective flow
semantics; tools remain in operation cards and accessible descriptions.
Payload colors are curated semantic roles, not arbitrary author colors.

Ordinary connectors draw behind cards. Adjacent same-lane handoffs are
horizontal. Cross-lane forward handoffs exit right and enter the top or bottom
with one soft bend. Forward skips are valid. A single labelled backward trigger
uses a reserved return band with appropriate top/bottom ports and a three-bend
route; the route must clear other cells and headers and must not cross its own
operation. Trigger styling is always neutral/dashed. If measured text, ports,
or a route cannot fit faithfully, rendering raises `SlimGraphR::LayoutError`
instead of crossing, clipping, or silently changing the diagram.

The bounded model requires at least one operation and allows 1–6 lanes, 1–12
stages, at most 24 operations, one operation per lane/stage cell, and at most
24 ordinary handoffs plus one optional trigger. It requires exactly one focal
stage and one focal operation. Process lane keys are unique after
normalization and must render as one to three characters. Empty cells mean no
work by that actor. Conversions, parallel gateways, multiple backward edges,
same-stage edges, custom colors, icons, vertical lanes, and arbitrary
coordinates are outside this slice.

The generated accessible description names every lane key, numbered stage,
empty cell meaning, operation, tool, payload, handoff, trigger, and effective
focal/accent, ordinary, or neutral/dashed style. The rendered SVG must be
checked in a real browser page at the intended width; a successful SVG string
alone does not establish readable geometry. This is bounded partial parity
with the pinned [Cathryn Lavery Diagram Design process
reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-process.md).
SlimGraphR is independent; upstream MIT attribution remains in
`vendor/diagram-design`.

## UTF-8 checks under a C locale

The sample title includes a literal middle dot. Check UTF-8 source and JSON
fixtures under a C locale in both executable paths:

```sh
LC_ALL=C LANG=C ruby -Ilib examples/standalone/process.rb
LC_ALL=C LANG=C ruby -Ilib exe/slimgraph render examples/standalone/process.json -o /tmp/process.svg
LC_ALL=C LANG=C slimgraph render examples/standalone/process.json -o /tmp/process-installed.svg
```

These commands are release checks for the implementation lane; this
documentation lane does not install packages or run browser tests.
