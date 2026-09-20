# Swimlane diagrams

Use `:swimlane` to show who performs each activity across an ordered set of
stages. A swimlane has actor lanes, numbered stages, at most one activity in
each lane/stage cell, and explicit handoffs. Use `:process` when the same
workflow also needs a tool and payload audit.

## Standalone Ruby

Declare lanes and stages, then place each activity with its lane and stage.
Activity labels are the second positional Ruby argument; IDs are stable
references and labels are what readers see. Activities may add measured
`detail:` copy and one `focal: true` outcome. A swimlane has no lane key or
focal stage. A handoff may add a label, `dashed: true` revision semantics, or
one `focal: true` critical handoff.

The shared document defaults are title `Diagram`, style `:editorial`, and
theme `:light`. Swimlane direction is fixed to `:right`. Omitted labels use
the library's humanized-ID default where that record permits an omitted label.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :swimlane,
  title: 'Survey workflow · pilot', style: :editorial, theme: :light do
  lane :research, 'Research'
  lane :delivery, 'Delivery'

  stage :design, 'Design'
  stage :build, 'Build'
  stage :review, 'Review'

  activity :draft_survey, 'Draft survey', lane: :research, stage: :design
  activity :build_app, 'Build app', lane: :delivery, stage: :build
  activity :approve, 'Approve', lane: :research, stage: :review

  handoff :draft_survey, :build_app
  handoff :build_app, :approve, focal: true
end

File.write('swimlane.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

`handoff from, to` is an ordinary forward connection. It may skip stages, but
it must advance through the ordered workflow and reference declared activity
IDs. A focal handoff is the only optional swimlane focus. Empty cells are
intentional: they mean that actor performs no activity at that stage.

## Equivalent strict JSON

JSON mirrors the Ruby records with `lanes`, `stages`, `activities`, and
`handoffs`. Activity and operation names use `label`, never a separate
`title`. The optional `focal` field belongs to a swimlane handoff only.

```json
{
  "type": "swimlane",
  "title": "Survey workflow · pilot",
  "style": "editorial",
  "theme": "light",
  "lanes": [
    {"id": "research", "label": "Research"},
    {"id": "delivery", "label": "Delivery"}
  ],
  "stages": [
    {"id": "design", "label": "Design"},
    {"id": "build", "label": "Build"},
    {"id": "review", "label": "Review"}
  ],
  "activities": [
    {"id": "draft_survey", "label": "Draft survey", "lane": "research", "stage": "design"},
    {"id": "build_app", "label": "Build app", "lane": "delivery", "stage": "build"},
    {"id": "approve", "label": "Approve", "lane": "research", "stage": "review"}
  ],
  "handoffs": [
    {"from": "draft_survey", "to": "build_app"},
    {"from": "build_app", "to": "approve", "focal": true}
  ]
}
```

Use the library parser for the same validated model:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('swimlane.json'))
File.write('swimlane.svg', diagram.to_svg)
diagram
```

The parser is strict and never evaluates JSON as Ruby. It rejects unknown,
null, wrongly typed, duplicate, or cross-type fields; duplicate IDs or cells;
missing lane/stage/activity references; same-stage or backward handoffs; and
generic `nodes`/`edges` forms. Labels may be omitted where the library's
humanized-ID default applies. Supplied labels must be nonblank strings.

Swimlane layout is fixed horizontal actor lanes with left-to-right stages; a
direction override is not accepted.

## CLI and optional StreamWeaver

The CLI chooses Ruby or JSON from the file extension:

```sh
slimgraph render swimlane.rb -o swimlane.svg
slimgraph render swimlane.json -o swimlane.html --format html
```

JSON is the stdin default; use `--input-format ruby` for Ruby source from
stdin. `--style` and `--theme` override presentation without changing the
model. A Ruby input must return its diagram as the final expression, as in the
example above. Output defaults to SVG, and `--format html` selects the small
HTML wrapper.

StreamWeaver is optional. A StreamWeaver document loads
`require 'slim_graph_r/stream_weaver'` and uses the same `diagram :swimlane`
block and DSL body. The core renderer has no runtime dependency on
StreamWeaver.

## Layout, semantics, and limits

The actor column is 140px wide. Stages are 112px wide, lanes are 80px high,
and activity cards are 100×64px. Stages number contiguously in declaration
order. Connectors render behind cards. Adjacent same-lane handoffs are
horizontal; cross-lane handoffs leave at the right and enter at the top or
bottom with one soft bend. Forward skips are valid. Labels, headers, cards,
and ports are measured before placement, and a route that cannot clear another
cell or a header raises `SlimGraphR::LayoutError` instead of crossing or
clipping content.

The bounded model requires at least one activity and allows 1–6 lanes, 1–12
stages, at most 24 activities, one activity per lane/stage cell, and at most
24 explicit handoffs. A swimlane may have zero or one focal activity and zero
or one focal handoff, preferably across lanes. It has no backward trigger,
conversion step, parallel gateway,
custom coordinate, vertical-lane mode, or authored style knob for ordinary
edges. Do not infer work for empty cells or invent conversions and gateways.
If a workflow needs those semantics, split it or use a supported diagram type.

The generated accessible description names each lane, numbered stage,
activity, empty cell meaning, handoff, and effective focal/ordinary flow. A
successful SVG string is serialization evidence; inspect a real browser page
at the intended width because a narrow page can expose a measured-layout
failure. The implementation is bounded, partial parity with the pinned
[Cathryn Lavery Diagram Design swimlane reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-swimlane.md).
SlimGraphR is independent; the upstream MIT notice and attribution remain in
`vendor/diagram-design`.

## UTF-8 checks under a C locale

The sample title includes a literal middle dot. Run source and installed
examples with an explicit C locale to verify that UTF-8 labels survive the
render path:

```sh
LC_ALL=C LANG=C ruby -Ilib examples/standalone/swimlane.rb
LC_ALL=C LANG=C ruby -Ilib exe/slimgraph render examples/standalone/swimlane.json -o /tmp/swimlane.svg
LC_ALL=C LANG=C slimgraph render examples/standalone/swimlane.json -o /tmp/swimlane-installed.svg
```

These are release checks for the implementation lane; the documentation lane
does not install packages or run browser tests.
