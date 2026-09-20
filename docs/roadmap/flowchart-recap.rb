# streamweaver-doc: v1
header1 'Flowcharts that mean what they draw'
text 'SlimGraphR 0.3.0 completes the first flowchart and shared-connector parity slice.'
implementation_map files: [
  {path: 'lib/slim_graph_r/diagram.rb', note: 'Start, decision, merge and finish vocabulary, with semantic validation'},
  {path: 'lib/slim_graph_r/layout/graph.rb', note: 'Shape-aware sizing and ports; conventional simple branches; reserved paths and label space'},
  {path: 'lib/slim_graph_r/svg.rb', note: 'Real diamonds, terminators and junctions, plus visible crossing hops'},
  {path: 'spec/flowchart_spec.rb', note: 'Semantic, geometry and intentionally crossed-path regression evidence'},
  {path: 'examples/stream_weaver/flowcharts.rb', note: 'The live light/dark example and exportable source'}
]
header2 'Verified'
text '46 RSpec examples pass. Published StreamWeaver 0.3.0 integration checks pass. The clean-package check renders the core without StreamWeaver, including the new full flowchart example.'
text 'Browser checked at desktop and 390px; horizontal overflow stays within each diagram. The independent review approved the slice, and the canonical design notes are updated.'
header2 'Still partial parity'
text 'The 39-type matrix remains honest: five partial types, 34 missing. Legends, full editorial reference variants, sequence activations/frames, and a true time axis still need work.'
md "```ruby\nstart :request\ndecision :valid, 'Complete?'\nstep :process\nstep :repair\nmerge :joined\nfinish :done\n```"
