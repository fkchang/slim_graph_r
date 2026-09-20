# Pyramid and funnel diagrams

Use `:pyramid` for a ranked hierarchy or a measured conversion funnel. It is
a dedicated model, with two explicit modes and two orientations. Hierarchy is
ordinal: its taper communicates rank and makes no quantity claim. Measured is
quantitative: every horizontal face is proportional to the declared amount.

## Standalone Ruby

Declare levels from the broad end to the narrow end. `orientation` defaults to
`:pyramid` and `mode` to `:hierarchy` in Ruby and JSON. A funnel requires
`mode: :measured`; hierarchy is pyramid-only. A focal level is optional and
may occur once, never at the base.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :pyramid,
  title: 'Audience qualification', orientation: :funnel,
  mode: :measured, unit: 'accounts' do
  level :reach, 'Reach', from: 12_000, to: 4_800
  level :engage, 'Engage', from: 4_800, to: 1_440
  level :qualify, 'Qualify', from: 1_440, to: 420, focal: true
  level :convert, 'Convert', from: 420, to: 126
end

File.write('audience.svg', diagram.to_svg)
diagram # Keep the diagram as the final expression for the Ruby CLI.
```

For an unquantified hierarchy, omit `orientation`, `mode`, `unit`, `from`,
and `to`; use four to six levels with optional `detail` text. The default
silhouette interpolates from a 480px base to a 96px apex at 64px per level.

## Equivalent strict JSON

JSON uses `orientation`, `mode`, `unit`, and `levels`. A level accepts only
`id`, `label`, `detail`, `from`, `to`, and `focal`; omitted `focal` is false.
The following document is field-for-field equivalent to the Ruby example.

```json
{
  "type": "pyramid",
  "title": "Audience qualification",
  "orientation": "funnel",
  "mode": "measured",
  "unit": "accounts",
  "levels": [
    {"id":"reach", "label":"Reach", "from":12000, "to":4800},
    {"id":"engage", "label":"Engage", "from":4800, "to":1440},
    {"id":"qualify", "label":"Qualify", "from":1440, "to":420, "focal":true},
    {"id":"convert", "label":"Convert", "from":420, "to":126}
  ]
}
```

Load the same model through the library parser:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('audience.json'))
File.write('audience.svg', diagram.to_svg)
diagram
```

The parser is strict. Unknown, null, cross-type, duplicate-ID, and malformed
level fields fail with `SlimGraphR::Error`. Ruby and JSON share defaults and
validation; neither accepts `direction:` or generic graph collections.

## CLI and optional StreamWeaver

```sh
slimgraph render audience.rb -o audience.svg
slimgraph render audience.json -o audience.html --format html
```

JSON is the stdin default; use `--input-format ruby` for Ruby stdin. `--style`
and `--theme` are presentation overrides. StreamWeaver is optional and loaded
explicitly with `require 'slim_graph_r/stream_weaver'`; the same pyramid body
then runs in a StreamWeaver document.

## Measured fidelity and limits

Measured levels require a nonblank shared `unit`, an initial `from > 0`, and
finite nonnegative boundaries. Each `to` is at most its `from`, and adjacent
levels share the exact boundary (`previous.to == next.from`). Equal adjacent
counts are valid and must remain equal. A conversion to zero is valid; after
the first zero, `0 → 0` tail bands may remain. No fictional loss, positive
minimum width, or area/readability floor may be introduced.

The two faces of each band use `480 * amount / first.from`, reversed only by
the chosen orientation. Labels contain the complete value and unit. If that
text cannot fit its true band, it moves to a collision-free outside right-side
leader slot; the renderer never widens a band or changes its quantity. Labels,
leaders, and serialized coordinates are measured. An unfaithful placement or
coordinate precision raises `SlimGraphR::LayoutError` with an actionable
message.

The bounded slice permits four to six levels, one optional focal level, and
one centered silhouette. It excludes decorative numeric funnels, mixed
orientation, authored axes/drop-off annotations, gradients, shadows, icons,
and arbitrary coordinates. Inspect a real rendered page at desktop and narrow
widths; an SVG string alone does not establish browser-page correctness.

Generated descriptions retain hierarchy versus measured meaning, orientation,
level labels/details, focal status, units, and measured boundaries. This is
partial parity with the pinned [Cathryn Lavery Diagram Design pyramid
reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-pyramid.md).
Outside leaders are an intentional adaptation that preserves exact widths.

## UTF-8 checks under a C locale

The source and installed-package checks should exercise the UTF-8 punctuation
already present in the shipped examples and both input forms without changing
its bytes. Use a dedicated UTF-8 fixture such as `入口` when checking literal
non-ASCII text:

```sh
LC_ALL=C LANG=C ruby -Ilib examples/standalone/pyramid.rb
LC_ALL=C LANG=C ruby -Ilib exe/slimgraph render examples/standalone/pyramid.json -o /tmp/pyramid.svg
LC_ALL=C LANG=C ruby -e 'require "slim_graph_r"; abort unless SlimGraphR::VERSION'
LC_ALL=C LANG=C slimgraph render examples/standalone/pyramid.json -o /tmp/pyramid-installed.svg
```

The first pair checks the checkout; the second pair checks the installed gem.
Use the same UTF-8 fixture for Ruby and JSON and verify the rendered output
retains the label. These are release checks, not a claim that this scratch
directory contains implementation artifacts.
