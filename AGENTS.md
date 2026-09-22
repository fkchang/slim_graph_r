# SlimGraphR

- Tests use RSpec. Run `bundle exec rspec`.
- Keep the public Ruby DSL small and readable; examples are executable contracts.
- The core renderer depends only on the extracted standard-library `bigdecimal` and `ostruct` gems. StreamWeaver integration is optional, loaded with `require 'slim_graph_r/stream_weaver'`.
- Preserve the approved editorial direction in DESIGN.md and upstream attribution in vendor/diagram-design.
- Verify layout geometry and real rendered examples. A successful SVG string or canvas push is not proof that its browser page works.
- Document explicit limits; raise actionable errors when a graph cannot be laid out faithfully.
