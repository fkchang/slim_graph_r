# SlimGraphR V0 parity fixtures

This directory vendors the 117 pinned baseline HTML assets used as development
and audit evidence: `minimal-light`, `minimal-dark`, and `full-editorial` for
each of the 39 baseline types.

Source: [Diagram Design](https://github.com/cathrynlavery/diagram-design),
revision `dcd9317ed9ec7477b20005544f36e3313664d815`.
Raw source URLs and SHA-256 digests are recorded in
`docs/roadmap/parity-fixtures-v0.json`. The upstream contract files and their
anchors are recorded there too. The upstream MIT license is retained in
`vendor/diagram-design/LICENSE`.

These files are development and audit evidence only. They are intentionally
excluded from the packaged gem and are not runtime renderer dependencies.
Preserve the original bytes; do not execute, normalize, or rewrite them.
