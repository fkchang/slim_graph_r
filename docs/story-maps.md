# User story map diagrams

Use `:story_map` to show one declared persona's narrative backbone and the
release slices cut across it. Activities and steps run in declaration order
from left to right; release bands answer where the first useful slice ends.
This is a planning explanation, not a Kanban board, user journey, calendar, or
priority ranking. One map has one person or role.

## Standalone Ruby

`persona:` is required and nonblank. Declare 2–5 activities, each with 1–2
steps, then 2–3 releases. Every release needs at least one story, and every
story references an existing activity. Exactly one release has `cut: true`; it
must not be the final release. A story may have one nonblank `estimate:` and
one nonblank `ticket:` plus optional `risk: true`. These are authored metadata:
the renderer neither derives them from position nor treats estimates as
priority. This UTF-8 title keeps all labels concise enough for their measured
cards.

```ruby
# encoding: UTF-8
require 'slim_graph_r'

diagram = SlimGraphR.diagram :story_map,
  title: 'Reporting first release · première coupe', persona: 'Analyst' do
  activity :find, 'Find the data' do
    step :search, 'Search catalogue'
    step :filter, 'Filter results'
  end
  activity :build, 'Build the report' do
    step :chart, 'Create chart'
  end
  activity :share, 'Share it' do
    step :send, 'Send report'
  end
  release :mvp, '2026-09-30', cut: true do
    story :saved_filter, 'Save filters', activity: :find,
      ticket: 'RPT-114', estimate: '3pt'
    story :templates, 'Use templates', activity: :build
  end
  release :later, 'Later' do
    story :permissions, 'Control report access', activity: :share, risk: true
  end
end

File.write('story-map.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

`cut: true` draws the release cut immediately below that release band. Only
one cut is allowed, and it is never last. At most one story may carry `risk:
true`; it is an accent treatment, not a computed risk score. A release label is
literal author text, so a label such as `2026 Q4` remains text and carries no
calendar semantics.

## Equivalent strict JSON

JSON mirrors the Ruby records. The following document is field-for-field
equivalent; omitted `cut` and `risk` mean false and are never written as
`null`.

```json
{
  "type":"story_map",
  "title":"Reporting first release · première coupe",
  "persona":"Analyst",
  "activities":[
    {"id":"find","label":"Find the data","steps":[{"id":"search","label":"Search catalogue"},{"id":"filter","label":"Filter results"}]},
    {"id":"build","label":"Build the report","steps":[{"id":"chart","label":"Create chart"}]},
    {"id":"share","label":"Share it","steps":[{"id":"send","label":"Send report"}]}
  ],
  "releases":[
    {"id":"mvp","label":"2026-09-30","cut":true,"stories":[{"id":"saved_filter","label":"Save filters","activity":"find","ticket":"RPT-114","estimate":"3pt"},{"id":"templates","label":"Use templates","activity":"build"}]},
    {"id":"later","label":"Later","stories":[{"id":"permissions","label":"Control report access","activity":"share","risk":true}]}
  ]
}
```

Load the same model through the strict parser:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('story-map.json'))
File.write('story-map.svg', diagram.to_svg)
diagram
```

The root allowlist is
`{type,title,description,style,theme,persona,activities,releases}`. Activity
records allow `{id,label,steps}`, steps `{id,label}`, releases
`{id,label,cut,stories}`, and stories
`{id,label,activity,estimate,ticket,risk}`. Unknown, null, duplicate, malformed,
cross-type, or missing-reference fields fail explicitly. The renderer never
reorders or aggregates the authored narrative.
When `description:` is supplied, it replaces the generated accessible
description exactly; generated story-map semantics are not appended.

## CLI and optional StreamWeaver

```sh
ruby -Ilib exe/slimgraph render story-map.rb -o story-map.svg
ruby -Ilib exe/slimgraph render story-map.json -o story-map.html --format html
```

JSON is the stdin default; use `--input-format ruby` for Ruby stdin. `--style`
and `--theme` override presentation only. Ruby source must leave `diagram` as
its final expression. StreamWeaver remains optional: load
`require 'slim_graph_r/stream_weaver'` and use the same `diagram :story_map`
body in a StreamWeaver document. The core renderer has no runtime dependency
on StreamWeaver.

## Layout, semantics, and limits

The fixed layout reserves a 96px release-label margin, 200px activity columns,
24px gutters, and 16px right stroke padding. Backbone cards are 56px high,
with up to two 32px walking-skeleton step cards per activity column.
Alternating release bands use 48px measured story cards. A faint dashed column
guide remains visible in the gaps behind the cards. The release cut and
optional risk card are the only accent treatments.

The bounded budget is 12 stories total and 4 stories per release. Labels that
cannot fit, too many cards, or lane/card overlap raises
`SlimGraphR::LayoutError`; the renderer does not shrink text, invent stories,
or move stories across activities. Descriptions report persona, activities and
steps in order, release order and cut, and every story with supplied metadata
and risk. There is no state, sentiment, dependency, priority inference,
calendar planning, external-ticket lookup, drag/edit behavior, cross-activity
card, arbitrary row, or automatic release selection. Date-like labels are
ordinary literal text.

This is partial parity with the pinned [Cathryn Lavery Diagram Design story
map reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-story-map.md).
SlimGraphR is an independent implementation; upstream attribution and the MIT
notice remain under `vendor/diagram-design`.

## UTF-8 checks under a C locale

Use a literal fixture such as `入口` in both Ruby and JSON checks. The sample
title's middle dot and accented `é` must survive unchanged. These commands are
future release checks, not a claim that this scratch guide has source or
rendering artifacts:

```sh
LC_ALL=C LANG=C ruby -Ilib examples/standalone/story_map.rb
LC_ALL=C LANG=C ruby -Ilib exe/slimgraph render examples/standalone/story_map.json -o /tmp/story-map.svg
```

Inspect real desktop and narrow browser pages for card wrapping, cuts, guide
gaps, descriptions, and scroll behavior. An SVG string alone does not
establish browser-page correctness.
