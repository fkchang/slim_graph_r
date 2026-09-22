# Motion contract

> **Status: design proposal.** SlimGraphR 0.30.0 does not ship animation or a `motion:` argument. The APIs and records below define the intended compatibility target for future implementation.

SlimGraphR may eventually reveal an argument over time, but Ruby must remain the source of semantic truth. Ruby validates the model, computes geometry, renders every SVG element, and supplies ordered step descriptions. A small shared browser player advances already-rendered groups.

The first target patterns are inspired by Diagram Design's [fan-in queue](https://github.com/cathrynlavery/diagram-design/blob/main/skills/diagram-design/assets/example-queue-animated.html), [paired policy trace](https://github.com/cathrynlavery/diagram-design/blob/main/skills/diagram-design/assets/example-policy-trace-animated.html), and [secure paved road](https://github.com/cathrynlavery/diagram-design/blob/main/skills/diagram-design/assets/example-paved-road-animated.html). SlimGraphR will implement its own model, layout, renderer, and player under the upstream MIT attribution already vendored in this repository.

## Proposed common envelope

Every animated document exposes one stable protocol:

- A focusable `data-motion-root` with mode, step count, current step, and frame state.
- One or more SVG groups marked `data-motion-item` and `data-step`.
- A complete plain-language `aria-label` for each step.
- Previous, next, play, pause, and replay controls with 44px targets.
- Arrow-key, Home/End, Space, and replay-key operation.
- An `aria-live` status region that announces user-initiated changes.
- `motion=static` and exact-step query modes for deterministic output and tests.
- `prefers-reduced-motion`, print, and no-script fallbacks that show the complete final figure.
- Visibility pause and one shared timing/easing token set.

The generic player toggles cumulative visibility and current-step state. It contains no queue, policy, trust-boundary, node, connector, or rate logic.

## Pattern-specific semantics

| Pattern | Step behavior | Additional state |
|---|---|---|
| Fan-in queue | Reveal steady arrivals, burst/full queue, overflow, service, equilibrium | A later step may replace an earlier depth badge; rates, capacity, admitted work, and shed work remain textually explicit. |
| Policy trace | Reveal the same rule row on two traces at each step | The current row may receive focus; statuses distinguish pass, fail, skipped, and not reached; first divergence remains visible. |
| Secure paved road | Reveal approved build/deploy stages, blocked bypass, then audit | Forbidden paths stop at the boundary; decorative zones remain static; permitted and blocked meaning uses labels and line treatment as well as color. |

Replacement and current-focus behavior are expressed through renderer-owned classes and root data attributes. A pattern may not ship custom JavaScript.

## Proposed Ruby-side records

A future implementation should keep the motion layer small:

- `Motion::Storyboard`: mode, ordered steps, static-final description.
- `Motion::Step`: positive number, accessible label, semantic item IDs.
- Pattern records: sources/rules/zones, supplied values, and validated outcomes.
- Renderer mapping: semantic item ID to one or more SVG groups and optional replacement/current classes.

For the fan-in queue, Ruby must validate compatible rate units, positive finite capacity and service rate, depth not exceeding capacity, and explicitly named overflow/admitted outcomes. Derived values such as `shed_rate = max(total_arrival - service_rate, 0)` are rendered as derived values, never silently authored facts.

## Planned output modes

- Existing `to_svg` continues to render the complete final static frame with no player dependency.
- A future `to_html(motion: :steps)` would embed or reference the shared player and start at step zero.
- A future `to_html(motion: :reveal)` may autoplay once and remain controllable.
- A future `to_html(motion: :static)` would render the complete final frame with controls unavailable.
- A future StreamWeaver/extension implementation should use the same data contract and bundle the player under its CSP rather than execute document-authored scripts.

## Release gates

- Every step is understandable in an exact-step screenshot and through its accessible label.
- The final static frame contains every conclusion the animation reveals.
- Reduced-motion, print, no-script, standalone HTML, StreamWeaver, and the extension agree on the final semantics.
- Controls survive keyboard-only use, replay, visibility changes, and switching reduced-motion while playing.
- Pattern-specific replacement never leaves contradictory old and new state visible together.
- Tests operate on exact steps; they do not wait on wall-clock animation.
