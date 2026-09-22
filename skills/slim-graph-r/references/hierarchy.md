# Hierarchy and containment

**Supported:** `:org_chart`, `:tree`, `:nested`, `:layers`, `:pyramid`

| Reader must understand | Use | Avoid when |
|---|---|---|
| Human/team/agent ownership, reporting, escalation, and invocation | `:org_chart` | The items are merely taxonomy nodes. |
| One-parent decomposition or taxonomy | `:tree` | Cross-links, multi-parent nodes, or cycles matter; use `:dependency`. |
| One chain of scopes inside scopes | `:nested` | A parent has multiple children; use `:tree`. |
| Ordered abstraction or protocol bands | `:layers` | Nodes connect laterally or ordering is not meaningful. |
| Ranked hierarchy, or a measured conversion funnel | `:pyramid` | The data is arbitrary part-to-whole composition. |

## Evidence gate

Containment, reporting, dependency, and sequence are different claims. A measured funnel requires explicit continuous `from`/`to` quantities; a hierarchy pyramid makes no quantity claim.

## Smallest useful pattern

```ruby
SlimGraphR.diagram :tree, title: 'Service ownership' do
  root :platform, 'Platform' do
    child :api, 'API' do
      child :billing, 'Billing', focal: true
    end
  end
end
```

Read `docs/org-charts.md`, `docs/trees.md`, `docs/nested-containment.md`, `docs/layer-stacks.md`, and `docs/pyramids.md`.
