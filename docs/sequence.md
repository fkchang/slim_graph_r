# Sequence conversations

Sequence diagrams describe messages in order, who holds control, and which interactions are alternatives, optional, or repeated. They render as static, accessible SVG.

```ruby
SlimGraphR.diagram :sequence, title: 'Fetch a document', style: :ruby do
  participant :client
  participant :api, 'API', emphasis: true
  participant :store, 'Document store', kind: :store

  message :client, :api, 'Fetch document'
  activate :api do
    alt do
      branch 'cached' do
        reply :api, :client, 'Cached document'
      end
      branch 'not cached' do
        message :api, :store, 'Read document'
        activate :store do
          reply :store, :api, 'Document'
        end
        reply :api, :client, 'Document'
      end
    end
  end
end
```

## Control intervals

`activate :actor do ... end` creates an eight-pixel activation bar. The block closes the interval; there is no unbalanced manual activate/deactivate state to maintain. Activations can nest up to three levels per actor, with a four-pixel offset at each level. A self-call followed by a nested activation anchors its return to the inner bar.

An immediately preceding incoming message in the same scope starts the activation on that arrow. After a scope or frame closes, a following activation starts at the current position unless a fresh incoming message precedes it. This keeps independent sibling activations disjoint. Bars end after their block's final message, including messages inside a combined frame.

## Message kinds

| Ruby | Meaning | Stroke and head |
| --- | --- | --- |
| `message :a, :b, 'Call'` | Synchronous call | Solid, filled |
| `reply :b, :a, 'Result'` | Return | Dashed, filled |
| `notify :a, :b, 'Event'` | Asynchronous notification | Dashed, open |
| `message :b, :a, 'Ready', kind: :success` | Headline success | Solid accent, filled |

`message` also accepts `kind: :call/:return/:async/:success`. Both `reply` and `notify` accept a positional label or `label:`. Existing sequence messages using `dashed: true` become return messages; specify `kind: :async` for notifications. Explicit flags that contradict the kind are rejected. Up to two success messages are allowed independently of participant emphasis.

Long cross-participant labels wrap in a gap between lifelines. Self-message labels sit to the right of the loop; the loop grows vertically to fit them.

## Combined frames

```ruby
alt do
  branch 'valid token' do
    reply :api, :client, 'Document'
  end
  branch 'expired token' do
    reply :api, :client, 'Refresh required'
  end
end

opt 'record metrics' do
  notify :worker, :metrics, 'Finished'
end

loop 'retry at most three times' do
  message :worker, :queue, 'Poll'
  reply :queue, :worker, 'Status'
end
```

These illustrate separate patterns; a single diagram allows one `alt`, or at most two `opt`/`loop` frames. `alt` requires exactly two nonempty `branch` blocks. `opt` and `loop` require a nonblank guard and at least one message. Every block is evaluated once. In this DSL, `loop` draws repetition rather than executing the body repeatedly; use ordinary Ruby iteration explicitly when generating data.

Frames cannot nest in this release. Activations may wrap frames or appear inside their regions. Participant declarations belong at the top level. Frame participants must occupy adjacent positions in the declared participant order; otherwise layout raises an actionable error rather than enclosing an unrelated lifeline. A trailing uninvolved participant remains outside the frame. Labels, operator tabs and region dividers have reserved vertical space.

Sequences are bounded to five participants and twelve messages, counting all displayed alternative branches. Split larger explanations into overview and detail. Participant creation/destruction and other UML operators (`par`, `critical`, `break`, `ref`) are not implemented.

## JSON and integration

Flat sequence `edges` remain supported, including message `kind`. For control structure use `steps`, as in [sequence_frames.json](../examples/standalone/sequence_frames.json). Do not supply both `edges` and `steps`.

```json
{"activate":"api","steps":[
  {"opt":"cached","steps":[
    {"message":{"from":"api","to":"client","label":"Result","kind":"return"}}
  ]}
]}
```

The full JSON example and Ruby example produce the same SVG when given the same explicit SVG ID. The CLI and optional StreamWeaver component use the same renderer. Frame conditions and activation scopes are preserved in the accessible description; `description:` can supply a concise custom summary.

This is an upstream-parity slice. Full editorial presentation and the complete reference-variant audit remain on the roadmap.
