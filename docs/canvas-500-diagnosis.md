# Canvas 500 diagnosis — 2026-09-08

Confirmed root cause for the current failure: the installed StreamWeaver bridge renders under US-ASCII and interpolates a bundled UTF-8 asset read without an explicit encoding. This is reproducible even for an empty canvas, independent of the diagram plan content.

## Evidence
- GET http://localhost:4700/canvas/slim-graph-plan returns HTTP 500.
- GET http://localhost:4700/health returns status=ok. That probe tests liveness, not page rendering.
- `~/.streamweaver/canvas.log` repeatedly records `Encoding::CompatibilityError: incompatible character encodings: UTF-8 and US-ASCII` at installed `lib/stream_weaver/canvas/bridge_server.rb:268`, inside `render_canvas_page`. Similar log entries occur September 7 and earlier September 8.
- Current shell: LC_ALL=C; Ruby Encoding.default_external=US-ASCII. LANG=C.UTF-8 is overridden by LC_ALL.
- PID 96528, port 4700, runs installed `stream_weaver-0.3.0`. Its generated `~/.streamweaver/canvas_start.rb` has no encoding preamble. Installed client uses plain spawn; installed bridge reads sw-mermaid-zoom.js without encoding.
- Canonical checkout `~/work/rstreamlit/stream_weaver` already contains commit d2550abea3fd38c67c82b536465b948f4dec58b5, dated September 7: `fix(canvas): force UTF-8 boot encoding for detached bridge/listener spawns`. That fix is absent from the installed gem files inspected here.
- The earlier panel command attempted automatic stale-code recovery but reported `JSON::GeneratorError: "\xE2" on US-ASCII`. The subsequent Unicode stdin push failed at cli.rb:1252 (`strip`). Retrying the push with a UTF-8 locale succeeded, but did not change the existing daemon's encoding; page requests still fail.

## Isolated reproduction (no running bridge changes)
Run this with the installed gem, first under `LC_ALL=C ruby`, then under `LC_ALL=C ruby -E UTF-8`:

```ruby
require 'stream_weaver'
require 'stream_weaver/canvas/bridge_server'
session = StreamWeaver::Canvas::Session.new('encoding-probe')
StreamWeaver::Canvas::BridgeServer.allocate.send(
  :render_canvas_page, 'encoding-probe', session
)
puts 'render OK'
```

Observed: plain Ruby raises the exact CompatibilityError at bridge_server.rb:268; `-E UTF-8` renders successfully. The probe only renders in memory, does not start a server, and does not add a live session.

## Dedicated fix-session scope
1. Read the StreamWeaver AGENTS.md and use its Tyrion workflow. Preserve unrelated checkout changes.
2. Inspect existing commit d2550ab and `spec/canvas/bridge_encoding_spec.rb` before implementing anything new. Determine why the installed gem has not picked it up (or was overwritten); deployment history was not investigated here.
3. Verify/install the intended source revision and restart with session preservation under UTF-8. Ensure the snapshot/restore caller itself starts with UTF-8, not only the child daemon. Check CLI stdin, history reads, and snapshot JSON separately: the daemon startup fix may not cover these caller-side boundaries.
4. Confirm the installed executable/gem and bridge all use the intended code. Avoid alternating old installed-gem and checkout commands that can trigger conflicting auto-restarts.
5. Verify an actual canvas page returns 200, both empty and with punctuation/Unicode, under LC_ALL=C and with locale variables unset. Verify snapshot/restart/restore preserves existing sessions.
6. Consider a render readiness check or actionable diagnostics: a successful /health and successful canvas-push currently do not establish that the browser page can render.

No StreamWeaver source was modified, no gem was installed, and no bridge restart was performed during this diagnosis. Existing plan content remains in history. The earlier planning turn did trigger StreamWeaver's own automatic restart attempt; that is the source of the startup/recovery evidence above.
