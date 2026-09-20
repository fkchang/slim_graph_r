# streamweaver-doc: v1
header1 'Show the conversation, including the alternatives'
text 'Next parity slice: scoped activation bars, conditional and repeating frames, and distinct call/return/async message arrows.'
implementation_map files: [
  {path: 'lib/slim_graph_r/sequence_definition.rb', note: 'A compact block DSL that preserves activation and branch meaning'},
  {path: 'lib/slim_graph_r/layout/sequence.rb', note: 'Lay out control intervals, guards and messages without collisions'},
  {path: 'lib/slim_graph_r/svg.rb', note: 'Render activation bars, combined frames and semantic markers'},
  {path: 'lib/slim_graph_r/document.rb + spec', note: 'Keep JSON, Ruby, CLI and StreamWeaver behavior equivalent'}
]
text 'Static SVG remains the output. loop describes repetition; it does not repeatedly execute Ruby. This is another parity slice, not a full 39-type certification.'
