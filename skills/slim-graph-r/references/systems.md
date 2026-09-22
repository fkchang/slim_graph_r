# Systems and relationships

**Supported:** `:architecture`, `:dependency`, `:deployment`, `:high_level`, `:data_flow`, `:dp_integration`

| Reader must understand | Use | Avoid when |
|---|---|---|
| Responsibilities and important paths among bounded components | `:architecture` | Package fan-in, physical placement, or role-by-stage work is the real subject. |
| What requires what, including shared requirements or a real cycle | `:dependency` | Each item has exactly one parent; use `:tree`. |
| Where software runs: zones, infrastructure, replicas, artifacts, protocols | `:deployment` | You only need logical responsibilities. |
| A platform overview with sources, phases, orchestration, and crosscuts | `:high_level` | Readers need service-level behavior or detailed topology. |
| Who transfers which payload, at which stage, using which tool | `:data_flow` | Pure message order matters more; use `:sequence`. |
| Sources, a bounded data-platform core, consumers, and declared wires | `:dp_integration` | The system is not a data platform. |

## Evidence gate

Name every node and relationship from supplied facts. A line does not mean healthy traffic, observed calls, or live capacity. Architecture trust boundaries require explicit allowed and blocked routes; otherwise describe them in prose rather than implying security.

## Smallest useful pattern

```ruby
SlimGraphR.diagram :architecture, title: 'Publishing path' do
  external :reader, 'Reader'
  node :app, 'Web app', emphasis: true
  store :db, 'Database'
  flow :reader, :app
  edge :app, :db, 'Read'
end
```

Read `docs/dependencies.md`, `docs/deployments.md`, `docs/high-level.md`, `docs/data-flows.md`, and `docs/platform-integrations.md`. Inspect `examples/stream_weaver/gallery.rb` for rendered examples.
