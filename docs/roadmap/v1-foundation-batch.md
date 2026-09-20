# V1 Foundation baseline verification batch

Foundation minimal-light/minimal-dark verification is the next bounded pass.

## Scope

- architecture
- flowchart
- sequence
- timeline
- org chart / responsibility
- state machine
- dependency graph
- deployment

## Baseline case references

Type | minimal-light | minimal-dark | upstream anchor
--- | --- | --- | ---
Architecture | supported-verified | supported-verified | tmp/upstream-types/type-architecture.md:75
Flowchart | supported-verified | supported-verified | tmp/upstream-types/type-flowchart.md:20
Sequence | supported-verified | supported-verified | tmp/upstream-types/type-sequence.md:124
Timeline | supported-verified | supported-verified | tmp/upstream-types/type-timeline.md:17
Org Chart / Responsibility Map | supported-verified | supported-verified | tmp/upstream-types/type-org-chart.md:41
State Machine | supported-verified | supported-verified | tmp/upstream-types/type-state.md:18
Dependency Graph | supported-verified | supported-verified | tmp/upstream-types/type-dependency.md:40
Deployment | supported-verified | supported-verified | tmp/upstream-types/type-deployment.md:41

## Gate plan

1. Render each case in StreamWeaver using the existing `slim-graph-plan` canvas.
2. Verify geometry, label clearance, contrast, and accessibility text per case.
3. Record any mismatch as actionable layout or contract defects before promoting any `verified_variants`.
4. Stop at the end of this batch unless a new blocker requires a targeted follow-up.
