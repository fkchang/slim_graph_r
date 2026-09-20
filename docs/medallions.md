# Medallion diagrams

Use `:medallion` for a left-to-right data-storage promotion chain. Each tier
is a distinct quality/access level of the same dataset, with its bucket,
tool, format, writer, and one or two concrete examples visible in a fixed
card. Use `:process` for role lanes and `:high_level` for cluster architecture.

## Standalone Ruby

Declare tiers in promotion order. The model has three to six tiers, exactly
one focal tier, optional final archive, adjacent promotions, and zero to two
write paths. Ruby and JSON use the same defaults: omitted `focal`, `archive`,
and `concern` mean false, false, and none; omitted paths mean an empty list.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :medallion, title: 'Survey storage tiers' do
  tier :raw, 'Raw', bucket: 'raw-bucket', tool: 'NiFi write',
       format: 'CSV · JSON', writer: 'Data Engineering',
       examples: ['source export']
  tier :anon, 'Anonymized', bucket: 'anon-bucket', tool: 'Trino INSERT',
       format: 'Iceberg', writer: 'Data Engineering',
       examples: ['stable household ID'], concern: :security
  tier :aggregate, 'Aggregated', bucket: 'metrics-bucket', tool: 'Trino',
       format: 'Iceberg indicators', writer: 'Data Science',
       examples: ['employment rate'], focal: true
  tier :archive, 'Archive', bucket: 'cold-bucket', tool: 'Lifecycle policy',
       format: 'immutable objects', writer: 'Data Administration',
       examples: ['annual snapshot'], archive: true
  promote :raw, :anon, 'REMOVE PII'
  promote :anon, :aggregate, 'AGGREGATE'
  promote :aggregate, :archive, 'LIFECYCLE'
  write_path :sql, tag: 'SQL PATH', title: 'INSERT INTO … SELECT',
             detail: 'set-based transforms'
end

File.write('survey-medallion.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

## Equivalent strict JSON

JSON accepts `tiers`, `promotions`, and `write_paths`. Tier fields are
`id`, `label`, `bucket`, `tool`, `format`, `writer`, `examples`, `focal`,
`archive`, and `concern`; promotion fields are `from`, `to`, and `label`;
path fields are `id`, `tag`, `title`, `detail`, and `concern`.

```json
{
  "type": "medallion",
  "title": "Survey storage tiers",
  "tiers": [
    {"id":"raw", "label":"Raw", "bucket":"raw-bucket", "tool":"NiFi write", "format":"CSV · JSON", "writer":"Data Engineering", "examples":["source export"]},
    {"id":"anon", "label":"Anonymized", "bucket":"anon-bucket", "tool":"Trino INSERT", "format":"Iceberg", "writer":"Data Engineering", "examples":["stable household ID"], "concern":"security"},
    {"id":"aggregate", "label":"Aggregated", "bucket":"metrics-bucket", "tool":"Trino", "format":"Iceberg indicators", "writer":"Data Science", "examples":["employment rate"], "focal":true},
    {"id":"archive", "label":"Archive", "bucket":"cold-bucket", "tool":"Lifecycle policy", "format":"immutable objects", "writer":"Data Administration", "examples":["annual snapshot"], "archive":true}
  ],
  "promotions": [
    {"from":"raw", "to":"anon", "label":"REMOVE PII"},
    {"from":"anon", "to":"aggregate", "label":"AGGREGATE"},
    {"from":"aggregate", "to":"archive", "label":"LIFECYCLE"}
  ],
  "write_paths": [
    {"id":"sql", "tag":"SQL PATH", "title":"INSERT INTO … SELECT", "detail":"set-based transforms"}
  ]
}
```

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('survey-medallion.json'))
File.write('survey-medallion.svg', diagram.to_svg)
diagram
```

Unknown, null, cross-type, duplicate-ID, missing-reference, and wrong-type
fields fail with actionable errors. A promotion appears exactly once for each
adjacent pair and labels are uppercased, nonblank, and at most 14 characters.

## CLI and optional StreamWeaver

```sh
slimgraph render survey-medallion.rb -o survey-medallion.svg
slimgraph render survey-medallion.json -o survey-medallion.html --format html
```

JSON is the stdin default; use `--input-format ruby` for Ruby stdin. `--style`
and `--theme` override presentation without changing the model. StreamWeaver
is optional: load `slim_graph_r/stream_weaver` and use the same DSL body.

## Geometry, semantic color, and limits

Cards are 172×380px with 16px gaps, a 16px left pad, 100px right pad, and an
80px arc band. For `n` tiers, width is `16 + n*172 + (n-1)*16 + 100`.
Height is 476px without paths and 548px with paths. Optional path cards are
at y=476, h=56, with zero, one, or two entries. Promotion arcs are cubic,
adjacent-only, over the top, anchored at tier top-centers with controls at
y=0; arcs draw before cards. Card text uses measured two-line `<tspan>`
wrapping, never `foreignObject`; impossible fit raises `LayoutError`.

There is exactly one focal tier. An archive is optional, but there can be at
most one and it must be the final tier; archive and focal cannot coincide.

Write-path cards divide their available row into one full-width card or two
equal cards with a 16px gap. Within each card, the tag chip is sized from its
measured text plus 12px, then the title/detail lane begins 16px after the chip;
the renderer rejects a title or detail that cannot fit that distinct lane.

At most two tiers or paths may carry a semantic `concern`: `security`,
`quality`, `product`, or `analysis`. Concerns select the curated rust, slate,
olive, or gold role in each style and its dark token; arbitrary hex colors and
manual connector colors are outside this contract. A concern is forbidden on
focal or archive tiers. Incoming promotion precedence is `focal`, then
archive, then the target concern, then normal: focal gets the accent marker,
archive gets the dashed lifecycle marker, and a concerned target matches its
semantic color. Focal styling never applies to its outgoing promotion.

The bounded model excludes non-adjacent, backward, or bidirectional flows,
custom arcs, more than two paths/concerns, mixed card grammars, and arbitrary
coordinates. Generated descriptions name every tier's storage fields,
examples, concern, focal/archive role, promotion, and write path. This is
partial parity with the pinned [Cathryn Lavery Diagram Design medallion
reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-medallion.md).
The fixed `<tspan>` wrapping is an intentional portable-SVG adaptation.

## UTF-8 checks under a C locale

Use the same UTF-8 punctuation in the source and JSON fixtures (`·` in the
format field and `…` in the write-path title):

```sh
LC_ALL=C LANG=C ruby -Ilib examples/standalone/medallion.rb
LC_ALL=C LANG=C ruby -Ilib exe/slimgraph render examples/standalone/medallion.json -o /tmp/medallion.svg
LC_ALL=C LANG=C ruby -e 'require "slim_graph_r"; abort unless SlimGraphR::VERSION'
LC_ALL=C LANG=C slimgraph render examples/standalone/medallion.json -o /tmp/medallion-installed.svg
```

The first pair covers source execution and the second the installed package;
verify literal UTF-8 survives both renders. These release checks are recorded
for the implementation lane and are not run from this documentation scratch.
