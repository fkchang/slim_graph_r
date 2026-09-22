require_relative 'lib/slim_graph_r/version'

Gem::Specification.new do |s|
  s.name = 'slim_graph_r'
  s.version = SlimGraphR::VERSION
  s.summary = 'Editorial SVG diagrams from a small Ruby DSL'
  s.description = 'SlimGraphR turns compact Ruby or strict JSON into deterministic, accessible SVG diagrams with measured layout, honest semantics, and optional StreamWeaver integration.'
  s.authors = ['Forrest Chang']
  s.email = ['fkc_email-ruby@yahoo.com']
  s.homepage = 'https://github.com/fkchang/slim_graph_r'
  s.license = 'MIT'
  s.required_ruby_version = '>= 3.1'
  s.files = Dir['lib/**/*.rb', 'exe/*', 'skills/**/*', 'docs/for_llms.md', 'docs/benchmark.md', 'docs/usage.md', 'docs/json-input.md', 'docs/dependencies.md', 'docs/deployments.md', 'docs/it-current-state.md', 'docs/org-charts.md', 'docs/state-machines.md', 'docs/sequence.md', 'docs/timeline.md', 'docs/motion-contract.md', 'docs/roadmap/*.{md,json}', 'assets/concepts/ruby-press-v1.jpg', 'examples/**/*', 'vendor/**/*', 'README.md', 'CHANGELOG.md', 'LICENSE']
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
  s.files.reject! { |path| path.start_with?('vendor/diagram-design/assets/v0-baseline/', 'vendor/diagram-design/fonts/') }
  s.bindir = 'exe'
  s.executables = ['slimgraph']
  s.require_paths = ['lib']
  s.add_dependency 'bigdecimal', '>= 3.1', '< 5'
  s.add_dependency 'ostruct', '>= 0.6', '< 1'
  s.metadata['allowed_push_host'] = 'https://rubygems.org'
  s.metadata['source_code_uri'] = 'https://github.com/fkchang/slim_graph_r'
  s.metadata['changelog_uri'] = 'https://github.com/fkchang/slim_graph_r/blob/main/CHANGELOG.md'
  s.metadata['documentation_uri'] = 'https://github.com/fkchang/slim_graph_r#readme'
  s.metadata['bug_tracker_uri'] = 'https://github.com/fkchang/slim_graph_r/issues'
  s.metadata['rubygems_mfa_required'] = 'true'
  s.metadata['stream_weaver.extensions.v1'] = 'slim_graph_r/stream_weaver_extension'
end
