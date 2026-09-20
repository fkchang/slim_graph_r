require_relative 'lib/slim_graph_r/version'

Gem::Specification.new do |s|
  s.name = 'slim_graph_r'
  s.version = SlimGraphR::VERSION
  s.summary = 'Editorial SVG diagrams from a small Ruby DSL'
  s.authors = ['SlimGraphR contributors']
  s.license = 'MIT'
  s.required_ruby_version = '>= 3.1'
  s.files = Dir['lib/**/*.rb', 'exe/*', 'docs/for_llms.md', 'docs/benchmark.md', 'docs/usage.md', 'docs/json-input.md', 'docs/dependencies.md', 'docs/deployments.md', 'docs/it-current-state.md', 'docs/org-charts.md', 'docs/state-machines.md', 'docs/sequence.md', 'docs/timeline.md', 'docs/roadmap/*.{md,json}', 'assets/concepts/ruby-press-v1.png', 'examples/**/*', 'vendor/**/*', 'README.md', 'LICENSE']
  s.files += Dir['docs/high-level.md']
  s.files += Dir['docs/trees.md', 'docs/nested-containment.md', 'docs/layer-stacks.md']
  s.files += Dir['docs/pyramids.md', 'docs/medallions.md']
  s.files += Dir['docs/swimlanes.md', 'docs/processes.md']
  s.files += Dir['docs/gantt.md', 'docs/kanban.md']
  s.files += Dir['docs/journeys.md', 'docs/story-maps.md']
  s.files += Dir['docs/data-flows.md']
  s.files += Dir['docs/platform-integrations.md']
  s.files += Dir['docs/access-matrices.md']
  s.files += Dir['docs/entity-relationships.md']
  s.files += Dir['docs/database-schemas.md']
  s.files += Dir['docs/uml-classes.md']
  s.files += Dir['docs/quadrants.md']
  s.files += Dir['docs/venn.md']
  s.files += Dir['docs/loops.md']
  s.files += Dir['docs/fishbones.md']
  s.files += Dir['docs/wardley-maps.md']
  s.files += Dir['docs/bar-charts.md', 'docs/line-charts.md', 'docs/scatter-plots.md']
  s.files += Dir['docs/treemaps.md', 'docs/sankeys.md']
  s.files += Dir['docs/polar-charts.md', 'docs/radar-charts.md']
  s.files += Dir['docs/polar-charts.md', 'docs/radar-charts.md']
  s.files.reject! { |path| path.start_with?('vendor/diagram-design/assets/v0-baseline/', 'vendor/diagram-design/fonts/') }
  s.bindir = 'exe'
  s.executables = ['slimgraph']
  s.require_paths = ['lib']
  s.metadata['stream_weaver.extensions.v1'] = 'slim_graph_r/stream_weaver_extension'
end
