# streamweaver-doc: v1
header1 'A timeline should tell the truth about time'
text 'SlimGraphR 0.5.0 adds date-scaled timelines while keeping ordered milestones explicit.'
implementation_map files: [
  {path: 'lib/slim_graph_r/layout/editorial.rb', note: 'Parse dates, space events by elapsed days, add ticks, and alternate event labels'},
  {path: 'lib/slim_graph_r/svg.rb', note: 'Render the horizontal date axis, ticks and alternating callouts'},
  {path: 'lib/slim_graph_r/diagram.rb + document.rb', note: 'Expose scale: :date/:ordered/:auto through Ruby and JSON'},
  {path: 'spec/layout_spec.rb', note: 'Verify elapsed spacing, parse failures and auto selection'}
]
text 'A date axis never pretends that January 1 and March 21 are equally far apart. A milestone list can still use Today and Next, but it opts into :ordered.'
