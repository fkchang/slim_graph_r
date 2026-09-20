# User journey diagrams

Use `:journey` to show one declared persona's experience from stage to stage
and the ordinal sentiment authored for each stage. The curve communicates the
sequence of that experience; it is not a score, a workflow connector, or a
measurement of customers. Use `:story_map` when the question is which
narrative activities fit in which release slices.

## Standalone Ruby

`persona:` is required and may be a person's name or a role. Declare 2–6
stages in the order the persona experiences them. Every stage has one explicit
ordinal `sentiment:` and exactly one nonblank `action`; `touchpoint:` is
optional. The five sentiment values are `:high`, `:medium_high`, `:neutral`,
`:medium_low`, and `:low`. The map must have one unique lowest-sentiment
trough. This UTF-8 example keeps the labels short enough for their measured
stage cells.

```ruby
# encoding: UTF-8
require 'slim_graph_r'

diagram = SlimGraphR.diagram :journey,
  title: 'Trial to paid · première semaine', persona: 'Independent analyst' do
  stage :discover, 'Discover', sentiment: :high do
    action 'Compare plans'
    touchpoint 'Website'
  end
  stage :try, 'Try', sentiment: :medium_high do
    action 'Create a project'
    touchpoint 'App'
  end
  stage :limit, 'Hit the limit', sentiment: :low do
    action 'Upload a second project'
    touchpoint 'App'
    pain 'Usage limit is unclear'
  end
  stage :upgrade, 'Upgrade', sentiment: :neutral do
    action 'Choose a plan'
    touchpoint 'Checkout'
  end
end

File.write('journey.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

`pain` belongs only to the unique trough and may appear at most twice there.
The renderer does not lower, raise, or tie-break authored sentiments to make a
trough. A tied lowest supplied value raises an actionable bounded-scope error.

## Equivalent strict JSON

JSON uses `stages` and represents the same model with strings. The following
document is field-for-field equivalent to the Ruby example. Optional fields
are omitted rather than written as `null`.

```json
{
  "type":"journey",
  "title":"Trial to paid · première semaine",
  "persona":"Independent analyst",
  "stages":[
    {"id":"discover","label":"Discover","action":"Compare plans","touchpoint":"Website","sentiment":"high"},
    {"id":"try","label":"Try","action":"Create a project","touchpoint":"App","sentiment":"medium_high"},
    {"id":"limit","label":"Hit the limit","action":"Upload a second project","touchpoint":"App","sentiment":"low","pains":["Usage limit is unclear"]},
    {"id":"upgrade","label":"Upgrade","action":"Choose a plan","touchpoint":"Checkout","sentiment":"neutral"}
  ]
}
```

Load the same model through the strict document parser:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('journey.json'))
File.write('journey.svg', diagram.to_svg)
diagram
```

The root allowlist is `{type,title,description,style,theme,persona,stages}`;
stage records allow `{id,label,action,touchpoint,sentiment,pains}`. Unknown,
null, duplicate-ID, malformed, cross-type, non-ordinal, or numeric fields fail
explicitly. Pain outside the trough, more than two pains, a missing unique
trough, or a nonblank/fit failure is rejected; values are never inferred.
When `description:` is supplied, it replaces the generated accessible
description exactly; the generated journey summary is not appended.

## CLI and optional StreamWeaver

```sh
ruby -Ilib exe/slimgraph render journey.rb -o journey.svg
ruby -Ilib exe/slimgraph render journey.json -o journey.html --format html
```

JSON is the stdin default; use `--input-format ruby` for Ruby stdin. `--style`
and `--theme` are presentation overrides. A Ruby input leaves `diagram` as
its final expression. StreamWeaver is optional: load
`require 'slim_graph_r/stream_weaver'` and run the same `diagram :journey`
body in a StreamWeaver document. The core renderer has no runtime dependency
on StreamWeaver.

## Layout, semantics, and limits

The layout measures the left row-label margin from tracked row and sentiment
labels, with a 64px minimum; the current uppercase `TOUCHPOINTS` and level
labels resolve to 84px. It then uses 200px stage columns, 24px gutters, and a
4px right stroke padding. Centered headers sit above a 160px sentiment plot.
Only used named ordinal hairlines are shown, followed by `ACTIONS`, optional
`TOUCHPOINTS`, and the pain row. Every dot remains on its exact authored
ordinal level. The sole curved line is the data curve; it conveys stage order
and does not interpolate a continuous measurement. The trough dot and incoming
segment use the accent, and pain tags use the second allowed accent treatment.

Labels and pain tags may stack only inside their own stage. Stage cells begin
at 224px and a pain marker may expand its own cell in measured 4px increments
up to 304px; later cells move as a group, while authored ordinal dots remain
on their named levels. If text still cannot fit, or density leaves an
unresolved overlap, rendering raises `SlimGraphR::LayoutError`.
Generated descriptions name the persona, stage order, every action and
touchpoint, each ordinal sentiment, the trough, pains, and the visible caption
`Sentiment levels are ordinal, not measured scores`.

This bounded slice excludes multiple personas or curves, numeric scores,
time/date axes, inferred personas, state/WIP, arrows, owners, metrics,
custom rows, emoji, and process/system flows. It is partial parity with the
pinned [Cathryn Lavery Diagram Design user journey reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-journey.md).
SlimGraphR is an independent implementation; upstream attribution and the MIT
notice remain under `vendor/diagram-design`.

## UTF-8 checks under a C locale

Use a literal fixture such as `入口` when checking both source forms; the
middle dot and accented `é` in the example also exercise shipped UTF-8 text.
These are release checks for a future implementation, not evidence that this
scratch guide has rendered:

```sh
LC_ALL=C LANG=C ruby -Ilib examples/standalone/journey.rb
LC_ALL=C LANG=C ruby -Ilib exe/slimgraph render examples/standalone/journey.json -o /tmp/journey.svg
```

Inspect a real desktop and narrow browser page for curve, caption, wrapping,
pain placement, and scroll behavior. A successful SVG string alone does not
establish browser-page correctness.
