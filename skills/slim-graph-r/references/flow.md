# Flow, ownership, state, and time

**Supported:** `:flowchart`, `:process`, `:swimlane`, `:state`, `:sequence`, `:journey`, `:story_map`, `:gantt`, `:kanban`, `:timeline`

| Reader must understand | Use | Avoid when |
|---|---|---|
| Decision logic, branches, and merges | `:flowchart` | Valid lifecycle states or actor messages dominate. |
| Ordered work with actors, tools, payloads, and handoffs | `:process` | Only ownership lanes are needed; use `:swimlane`. |
| Who owns activity across numbered stages | `:swimlane` | Tools, payloads, or durations are the claim. |
| Valid states, events, guards, recovery, and terminal outcomes | `:state` | This is one observed request trace. |
| Time-ordered calls, replies, activations, and bounded alternatives | `:sequence` | Elapsed calendar time or work ownership matters more. |
| One persona's stages, actions, touchpoints, and ordinal sentiment | `:journey` | There is no research-supported persona experience. |
| Narrative activities sliced into releases with a cut line | `:story_map` | You need task dependencies or calendar scheduling. |
| Authored task durations, phases, milestones, and markers | `:gantt` | Only events, not durations, matter. |
| Current work by state, with cards and optional WIP limits | `:kanban` | You need historical flow or predicted completion. |
| A few events at exact elapsed dates or explicit authored order | `:timeline` | Tasks span intervals; use `:gantt`. |

## Evidence gate

Sequence order is not duration. Timeline spacing is not workload. Journey sentiment is ordinal judgment, not a measured score. Gantt dates are supplied plans; SlimGraphR does not calculate a critical path.

## Smallest useful pattern

```ruby
SlimGraphR.diagram :flowchart, title: 'Publishing decision' do
  step :draft, 'Prepare draft'
  decision :review, 'Ready to publish?'
  step :publish, 'Publish'
  flow :draft, :review
  edge :review, :publish, 'Approved'
end
```

Read the matching guide under `docs/` before using advanced frames, transitions, routing, planning metadata, or dense timelines.
