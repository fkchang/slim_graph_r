# Motion contract

> **Status: implemented thin motion layer.** Graph-backed diagrams can attach an immutable storyboard and render controllable standalone HTML. Ordinary SVG remains complete and static. Pattern-specific queue, policy, and security calculations remain authored facts rather than inferred behavior.

SlimGraphR can reveal an argument over time, while Ruby remains the source of semantic truth. Ruby validates the model, computes geometry, renders every SVG element, and supplies ordered step descriptions. A small shared browser player advances already-rendered groups.

The first examples are inspired by Diagram Design's [fan-in queue](https://github.com/cathrynlavery/diagram-design/blob/main/skills/diagram-design/assets/example-queue-animated.html), [paired policy trace](https://github.com/cathrynlavery/diagram-design/blob/main/skills/diagram-design/assets/example-policy-trace-animated.html), and [secure paved road](https://github.com/cathrynlavery/diagram-design/blob/main/skills/diagram-design/assets/example-paved-road-animated.html). SlimGraphR implements its own storyboard, renderer integration, and player under the upstream MIT attribution already vendored in this repository.

## Common envelope

Every animated document exposes one stable protocol:

- A focusable `data-sgr-motion-root` with mode, step count, current step, and frame state.
- One or more SVG groups marked `data-motion-item` and `data-step`.
- A complete plain-language `aria-label` for each step.
- Previous, next, play/pause, and replay controls with 44px targets.
- Arrow-key, Home/End, Space, and replay-key operation.
- An `aria-live` status region that announces user-initiated changes.
- `motion=static` and `motion=step&step=N` query modes for deterministic output and tests.
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

## Ruby API

The motion layer stays small:

- `Motion::Storyboard`: ordered, contiguous reveal steps.
- `Motion::Step`: positive number, accessible label, semantic item IDs, and optional replacements.
- `Motion::Presentation`: immutable pairing of one diagram and one storyboard.
- Renderer mapping: graph node IDs and explicit `route(:source, :target)` targets to SVG groups.

The thin layer does not calculate queue capacity, policy outcomes, or enforcement. Those remain explicit authored facts in the underlying diagram. A future dedicated queue type would need compatible rate units, positive finite capacity and service rate, and explicit admitted and shed outcomes before it could derive values honestly.

## Output modes

- `presentation.to_svg` renders the complete final static frame with no player dependency.
- `presentation.to_html(motion: :steps)` embeds the shared player and starts at step one.
- `presentation.to_html(motion: :reveal)` autoplays once and remains controllable.
- `presentation.to_html(motion: :static)` renders the storyboard's complete final frame without controls or script.
- StreamWeaver uses the same fragment and data contract. Its extension build bundles the SlimGraphR player as local CSP-compatible code rather than executing document-authored scripts.

```ruby
presentation = diagram.storyboard do
  reveal 1, :signed_commit, 'Signed commit enters the paved road'
  reveal 2, :build, route(:signed_commit, :build),
    'CI builds the artifact and records provenance'
end
```

Targets are graph node IDs or explicit `route(:source, :target)` objects. Steps are contiguous, a target is revealed once, and `replaces:` hides an earlier target from that step onward. Unsupported or missing targets raise an actionable error. Explicit route objects prevent collisions when node IDs contain hyphens.

## Release gates

- Every step is understandable in an exact-step screenshot and through its accessible label.
- The final static frame contains every conclusion the animation reveals.
- Reduced-motion, print, no-script, standalone HTML, StreamWeaver, and the extension agree on the final semantics.
- Controls survive keyboard-only use, replay, visibility changes, and switching reduced-motion while playing.
- Pattern-specific replacement never leaves contradictory old and new state visible together.
- Tests operate on exact steps; they do not wait on wall-clock animation.
