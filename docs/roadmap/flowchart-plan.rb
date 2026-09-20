# streamweaver-doc: v1
header1 'Flowcharts that mean what they draw'
text 'Next parity slice: real flowchart shapes and clearer shared connectors. Existing styles and CLI stay compatible.'
implementation_map files: [
  {path: 'lib/slim_graph_r/diagram.rb', note: 'Add start, finish and merge vocabulary, plus decision-branch validation'},
  {path: 'lib/slim_graph_r/layout/graph.rb', note: 'Size each shape for its text, attach arrows to its actual boundary and separate routed strokes'},
  {path: 'lib/slim_graph_r/svg.rb', note: 'Render diamonds, terminators and junctions, with labels clear of arrows'},
  {path: 'spec + examples', note: 'Verify meaning, geometry and real output across styles'}
]
text 'This is a conformance slice, not a claim of complete parity for all five original types. Sequence frames and a scaled timeline remain later steps.'
