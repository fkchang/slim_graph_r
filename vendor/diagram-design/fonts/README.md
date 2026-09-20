# Deterministic parity-capture fonts

These WOFF2 files are development and audit assets only. Playwright intercepts
the pinned Diagram Design pages' Google Fonts stylesheet request and serves
these exact binaries without changing the archived HTML files under
`vendor/diagram-design/assets/v0-baseline/`.

`script/parity-fonts.json` pins each file's SHA-256 and family/style/weight.
The capture fails before a screenshot if a file is absent or its digest differs,
or if Chromium cannot load every required face.

The binaries were downloaded from the Google Fonts CSS endpoint with Chromium's
font request URLs on 2026-09-15. Geist and Geist Mono are covered by
`GEIST-OFL.txt`; Instrument Serif is covered by `INSTRUMENT-SERIF-OFL.txt`.
They remain outside the gem runtime and package payload.
