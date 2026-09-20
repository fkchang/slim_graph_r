# Access-matrix diagrams

An access matrix answers one bounded question: what explicitly recorded
permission does each declared role have on each declared component? Use
`:dp_security_matrix` for a connector-free role × component matrix. It records
the author's cells exactly; it does not calculate effective access, inherit
grants, or fill gaps from names, groups, or neighboring cells.

## Standalone Ruby

Declare roles and components first, then one `permission` for every role and
component pair. A role may carry an optional literal directory/group `code:`.
A component may carry an optional literal `hint:`.

```ruby
require 'slim_graph_r'

diagram = SlimGraphR.diagram :dp_security_matrix,
  title: 'Recorded platform access · 0.19 · 権限表',
  style: :editorial, theme: :light do
  role :admins, 'Data administrators', code: 'DL-DataAdmins'
  role :engineers, 'Data engineers', code: 'DL-DataEngineers'
  role :consumers, 'Data consumers'

  component :raw, 'Raw store', hint: 'S3'
  component :aggregate, 'Aggregate catalog', hint: 'SQL'
  component :reports, 'Published reports', hint: 'BI'

  permission :raw, :admins, level: :admin
  permission :raw, :engineers, level: :write
  permission :raw, :consumers, level: :deny
  permission :aggregate, :admins, level: :admin
  permission :aggregate, :engineers, level: :write
  permission :aggregate, :consumers, 'Select only', level: :read,
             note: 'published aggregate', focal: true
  permission :reports, :admins, level: :read
  permission :reports, :engineers, level: :read
  permission :reports, :consumers, level: :read
end

File.write('access-matrix.svg', diagram.to_svg)
diagram
```

Under the shared document contract, `title` defaults to `Diagram`, `style` to
`:editorial`, and `theme` to `:light`; `description` is optional. Styles are
`:editorial`, `:ruby`, `:blueprint`, or `:mono`, and themes are `:light`,
`:dark`, or `:auto`. The matrix direction is fixed to `:down`.

`level:` is closed: `:admin`, `:write`, `:read`, `:deny`, or `:unknown`. Every
declared `(component, role)` coordinate needs exactly one explicit permission.
Omitting a coordinate is invalid; it never means `No access`. Use
`level: :unknown` when the author knows that access is not yet known. That is an
authored level and remains visible in the matrix.

The optional positional label overrides only the deterministic default selected
by the explicit level: `Admin`, `Read/write`, `Read`, `No access`, or `Unknown`.
For example, `permission :raw, :admins, 'Break-glass admin', level: :admin`
preserves a literal qualification without changing the category. A supplied
denial or unknown remains explicit. `note:` is an optional second-line
explanation allowed only on the zero-or-one focal permission. `focal: true`
does not change its permission level.

Role and component labels are required literal text. Optional `code:` and
`hint:` are omitted when that metadata was not recorded. No permission is
inherited from a role, component, code, hint, row, column, or other cell. Bulk
policy shorthands, connectors, coordinate calls, generic node/edge methods,
arbitrary colors, and row or column coloring are outside this type.

## Equivalent strict JSON

JSON uses the same explicit grid. It does not accept generic `nodes`, `edges`,
grants, or an omitted-cell convention.

```json
{
  "type": "dp_security_matrix",
  "title": "Recorded platform access · 0.19 · 権限表",
  "style": "editorial",
  "theme": "light",
  "roles": [
    {"id":"admins", "label":"Data administrators", "code":"DL-DataAdmins"},
    {"id":"engineers", "label":"Data engineers", "code":"DL-DataEngineers"},
    {"id":"consumers", "label":"Data consumers"}
  ],
  "components": [
    {"id":"raw", "label":"Raw store", "hint":"S3"},
    {"id":"aggregate", "label":"Aggregate catalog", "hint":"SQL"},
    {"id":"reports", "label":"Published reports", "hint":"BI"}
  ],
  "permissions": [
    {"component":"raw", "role":"admins", "level":"admin"},
    {"component":"raw", "role":"engineers", "level":"write"},
    {"component":"raw", "role":"consumers", "level":"deny"},
    {"component":"aggregate", "role":"admins", "level":"admin"},
    {"component":"aggregate", "role":"engineers", "level":"write"},
    {"component":"aggregate", "role":"consumers", "label":"Select only", "level":"read", "note":"published aggregate", "focal":true},
    {"component":"reports", "role":"admins", "level":"read"},
    {"component":"reports", "role":"engineers", "level":"read"},
    {"component":"reports", "role":"consumers", "level":"read"}
  ]
}
```

Load the same strict document through the library parser:

```ruby
require 'slim_graph_r/document'

diagram = SlimGraphR::Document.from_json(File.read('access-matrix.json'))
File.write('access-matrix.svg', diagram.to_svg)
diagram
```

The JSON root allowlist is
`{type,title,description,style,theme,roles,components,permissions}`. A role is
`{id,label,code}`, a component is `{id,label,hint}`, and a permission is
`{component,role,label,level,note,focal}`. Optional scalar fields are omitted,
never `null`; `label` is omitted when the level default is wanted, `note` is
omitted unless focal, and `focal` defaults to `false` only when omitted.
Unknown or cross-type keys, explicit `null`, wrong scalar types, blank text,
duplicate IDs or coordinates, invalid levels, and a partial grid fail with
`SlimGraphR::Error`.

## CLI and optional StreamWeaver

```sh
./exe/slimgraph render access-matrix.rb -o access-matrix.svg
./exe/slimgraph render access-matrix.json -o access-matrix.html --format html
slimgraph render access-matrix.json -o access-matrix-installed.svg
```

The extension selects Ruby or JSON. JSON is the stdin default; use
`--input-format ruby` for Ruby source from stdin. A Ruby CLI input must leave
`diagram` as its final expression. `--style` and `--theme` change presentation
without changing any recorded cell.

StreamWeaver is optional and loaded explicitly:

```ruby
require 'slim_graph_r/stream_weaver'

# Use the same SlimGraphR.diagram(:dp_security_matrix, ...) block above.
```

The core renderer has no runtime dependency on StreamWeaver. The optional
example is `examples/stream_weaver/dp_security_matrices.rb`.

## Layout, accessibility, and limits

The SVG has no connector elements. It uses a measured component-label column,
declaration-ordered role banners, and one visible body cell for every explicit
permission. Category treatment comes solely from the closed `level` value.
`:deny` and `:unknown` keep readable text and distinct neutral boundary
treatments. A focal border and note identify at most one declared critical rule
without changing its underlying level. The legend lists exactly the levels
present in the grid.

The canvas widens with roles and grows with components within these release
budgets: 2–5 roles, 2–10 components, 4–36 cells, and zero or one focal cell.
Names, codes, hints, labels, notes, uppercase headings, and tracked legend text
are measured against their reserved lanes. If content cannot fit, or if the
explicit grid is incomplete, rendering raises an actionable
`SlimGraphR::LayoutError` or construction raises `SlimGraphR::Error`. The
renderer never truncates, collapses, substitutes, infers, or moves a cell.

Generated accessibility text identifies every role and recorded code, every
component and hint, and every explicit permission, including the focal
annotation. Supplying `description:` replaces that generated prose with the
author's literal accessible description; it does not alter the matrix.

This is bounded partial parity with the pinned [Cathryn Lavery Diagram Design
DP-security-matrix reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-dp-security-matrix.md).
SlimGraphR remains an independent renderer; attribution and the upstream MIT
notice stay in `vendor/diagram-design`. Inheritance and effective-permission
computation, group expansion, policy flows, connectors, imports, arbitrary
colors, role or component highlighting, filters, sorting, audit timestamps,
and full upstream decorative variants remain deferred.
