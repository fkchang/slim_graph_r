# streamweaver-doc: v1
header1 'Express intention. Get the picture.'
text 'SlimGraphR 0.2.0: the adoption and style foundation is implemented.'
implementation_map files: [
  {path: 'README.md', note: 'A charged, intent-first draft with the accepted hero and real SVG output'},
  {path: 'exe/slimgraph + lib/slim_graph_r/cli.rb', note: 'Ruby and JSON rendering, safe output files, stdin/stdout and presentation overrides'},
  {path: 'lib/slim_graph_r/style.rb', note: 'Editorial, Ruby, Blueprint and Mono; light/dark/auto remains independent'},
  {path: 'examples/standalone + examples/stream_weaver', note: 'The core works alone; the StreamWeaver integration has its own examples'},
  {path: 'bin/check-package + .github/workflows/ci.yml', note: 'Isolated installation proof and separate core/integration CI jobs'}
]
header2 'Verified locally'
text '35 RSpec examples pass: 30 core examples with the core-only bundle, five integration examples with StreamWeaver 0.3.0. The isolated package check renders Ruby and JSON with StreamWeaver absent, even under LC_ALL=C.'
text 'All eight style/mode combinations were inspected in the browser. At 390px, the page stayed within the viewport and diagram overflow stayed within its scroll regions. Hosted CI has been configured, not run.'
header2 'Keep the promise honest'
text 'The current five diagram types are still partial implementations against upstream contracts. Full 39-type parity remains the target. Next: connector conformance, real flowchart shapes, sequence activations/frames, and an honest time axis.'
md "```sh\nslimgraph render examples/standalone/publishing.rb --style ruby -o publishing.html\n```"
