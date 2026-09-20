# streamweaver-doc: v1
header1 'Exact dates. Readable callouts.'
text 'Fixing timeline fidelity before expanding the diagram catalog.'
implementation_map files: [
  {path: 'lib/slim_graph_r/layout/editorial.rb', note: 'Sort dates, preserve exact positions, group simultaneous events and place labels without shifting data'},
  {path: 'lib/slim_graph_r/svg.rb', note: 'Keep callouts and ticks clear, identify the scale in the image and accessible description'},
  {path: 'lib/slim_graph_r/diagram.rb + cli.rb', note: 'Validate scale overrides consistently and expose them through the CLI'},
  {path: 'spec/timeline_spec.rb', note: 'Regression evidence for ratios, repeated dates, sorting, strict dates and dense inputs'}
]
text '0.5.0 moved markers at least 48px apart. That distorted crowded or out-of-order dates. The correction keeps data positions fixed; indistinguishable dates raise a clear error.'
