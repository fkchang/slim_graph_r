# Semantic patterns

Use a semantic pattern when the reader must understand behavior that a generic layout alone would hide. The pattern owns required facts and step meaning; the nearest diagram type owns spatial grammar.

## Fan-in queue / bottleneck → Data flow

Use when several producers converge on finite capacity and the story depends on arrival rate, queue depth, service rate, backpressure, or rejected work.

Require named sources, comparable units, explicit queue capacity, one constrained service point, and admitted plus deferred/rejected outcomes. Do not draw an equal-width pipeline that hides contention or imply overload through color alone.

## Paired policy-evaluation traces → Flowchart

Use when similar requests reach different outcomes and the reader needs the first rule where they diverge.

Require the same ordered rules on both traces, explicit `PASS`, `FAIL`, `SKIPPED`, and `NOT REACHED` states where applicable, the differing inputs, first-divergence annotation, and both outcomes. Never treat skipped and not reached as synonyms.

## Secure paved road → Architecture

Use when trust boundaries and the difference between an approved route and forbidden bypass are the claim.

Require labeled trust zones, identities, permitted ingress, a privileged gate, an approved deployment route, blocked paths that visibly stop before entry, an isolated runtime, and an audit destination. Do not use a dashed box labelled “security” as a substitute for route semantics.

## Motion

These patterns may eventually use ordered reveal, but animation cannot carry unique meaning. The complete final frame, step descriptions, print, no-script, and reduced-motion outputs must remain sufficient. A future shared protocol is proposed in `docs/motion-contract.md`; animation is not shipped in SlimGraphR 0.30.0.

Inspired by [Diagram Design's semantic-pattern research](https://github.com/cathrynlavery/diagram-design/blob/main/skills/diagram-design/references/semantic-patterns.md); this file narrows the patterns to SlimGraphR's supported Ruby contracts.
