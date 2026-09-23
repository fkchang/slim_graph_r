# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'the 0.30.0 package manifest' do
  it 'publishes complete, secure RubyGems metadata' do
    specification = Gem::Specification.load(File.expand_path('../slim_graph_r.gemspec', __dir__))

    expect(specification.authors).to eq(['Forrest Chang'])
    expect(specification.email).to eq(['fkc_email-ruby@yahoo.com'])
    expect(specification.description).to include('deterministic', 'accessible SVG')
    expect(specification.homepage).to eq('https://github.com/fkchang/slim_graph_r')
    expect(specification.metadata).to include(
      'allowed_push_host' => 'https://rubygems.org',
      'source_code_uri' => 'https://github.com/fkchang/slim_graph_r',
      'changelog_uri' => 'https://github.com/fkchang/slim_graph_r/blob/main/CHANGELOG.md',
      'documentation_uri' => 'https://github.com/fkchang/slim_graph_r#readme',
      'bug_tracker_uri' => 'https://github.com/fkchang/slim_graph_r/issues',
      'rubygems_mfa_required' => 'true'
    )
  end

  it 'declares its optional StreamWeaver University loader and ships its standalone course artifacts' do
    specification = Gem::Specification.load(File.expand_path('../slim_graph_r.gemspec', __dir__))

    expect(specification.metadata['stream_weaver.extensions.v1']).to eq('slim_graph_r/stream_weaver_extension')
    expect(specification.files).to include(
      'lib/slim_graph_r/stream_weaver_extension.rb',
      'lib/slim_graph_r/university/provider.rb',
      'lib/slim_graph_r/university/demos/standalone.rb',
      'lib/slim_graph_r/university/demos/semantic.rb',
      'lib/slim_graph_r/university/demos/canvas.rb'
    )
  end

  it 'ships Wardley contracts with only explicit extracted-standard-library dependencies' do
    specification = Gem::Specification.load(File.expand_path('../slim_graph_r.gemspec', __dir__))
    expect(specification.version.to_s).to eq('0.30.0')
    expect(specification.runtime_dependencies.map(&:name)).to eq(%w[bigdecimal ostruct])
    expect(specification.runtime_dependencies.fetch(0).requirement).to be_satisfied_by(Gem::Version.new('4.1.0'))
    expect(specification.runtime_dependencies.fetch(1).requirement).to be_satisfied_by(Gem::Version.new('0.6.3'))
    expect(specification.files).to include(
      'CHANGELOG.md',
      'lib/slim_graph_r/motion.rb',
      'lib/slim_graph_r/motion_player.rb',
      'lib/slim_graph_r/motion_patterns.rb',
      'docs/motion-contract.md',
      'examples/standalone/fan_in_queue_animated.rb',
      'examples/standalone/policy_trace_animated.rb',
      'examples/standalone/secure_paved_road_animated.rb',
      'examples/stream_weaver/motion.rb',
      'examples/stream_weaver/motion_patterns.rb',
      'lib/slim_graph_r/radial.rb',
      'lib/slim_graph_r/radial_svg.rb',
      'examples/standalone/polar.rb',
      'examples/standalone/polar.json',
      'examples/standalone/radar.rb',
      'examples/standalone/radar.json',
      'examples/stream_weaver/radial.rb',
      'docs/polar-charts.md',
      'docs/radar-charts.md'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/quantitative.rb',
      'lib/slim_graph_r/quantitative_svg.rb',
      'examples/standalone/bar.rb',
      'examples/standalone/bar.json',
      'examples/standalone/line.rb',
      'examples/standalone/line.json',
      'examples/standalone/scatter.rb',
      'examples/standalone/scatter.json',
      'examples/stream_weaver/cartesian.rb',
      'docs/bar-charts.md',
      'docs/line-charts.md',
      'docs/scatter-plots.md'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/area_conservation.rb',
      'lib/slim_graph_r/area_conservation_svg.rb',
      'examples/standalone/treemap.rb',
      'examples/standalone/treemap.json',
      'examples/standalone/sankey.rb',
      'examples/standalone/sankey.json',
      'examples/stream_weaver/area_conservation.rb',
      'docs/treemaps.md',
      'docs/sankeys.md'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/planning_boards.rb',
      'lib/slim_graph_r/layout/planning_boards.rb',
      'lib/slim_graph_r/planning_boards_svg.rb',
      'examples/standalone/gantt.rb',
      'examples/standalone/gantt.json',
      'examples/standalone/kanban.rb',
      'examples/standalone/kanban.json',
      'examples/stream_weaver/planning_boards.rb'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/journey.rb',
      'lib/slim_graph_r/layout/journey.rb',
      'lib/slim_graph_r/journey_svg.rb',
      'examples/standalone/journey.rb',
      'examples/standalone/journey.json',
      'examples/standalone/story_map.rb',
      'examples/standalone/story_map.json',
      'examples/stream_weaver/journey_family.rb'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/data_flow.rb',
      'lib/slim_graph_r/layout/data_flow.rb',
      'lib/slim_graph_r/data_flow_svg.rb',
      'examples/standalone/data_flow.rb',
      'examples/standalone/data_flow.json',
      'examples/stream_weaver/data_flows.rb'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/dp_integration.rb',
      'lib/slim_graph_r/layout/dp_integration.rb',
      'lib/slim_graph_r/dp_integration_svg.rb',
      'examples/standalone/dp_integration.rb',
      'examples/standalone/dp_integration.json',
      'examples/stream_weaver/dp_integrations.rb'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/dp_security_matrix.rb',
      'lib/slim_graph_r/layout/dp_security_matrix.rb',
      'lib/slim_graph_r/dp_security_matrix_svg.rb',
      'examples/standalone/dp_security_matrix.rb',
      'examples/standalone/dp_security_matrix.json',
      'examples/stream_weaver/dp_security_matrices.rb',
      'docs/access-matrices.md'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/er.rb',
      'lib/slim_graph_r/layout/er.rb',
      'lib/slim_graph_r/er_svg.rb',
      'examples/standalone/entity_relationships.rb',
      'examples/standalone/entity_relationships.json',
      'examples/stream_weaver/entity_relationships.rb',
      'docs/entity-relationships.md'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/db_schema.rb',
      'lib/slim_graph_r/layout/db_schema.rb',
      'lib/slim_graph_r/db_schema_svg.rb',
      'examples/standalone/database_schema.rb',
      'examples/standalone/database_schema.json',
      'examples/stream_weaver/database_schemas.rb',
      'docs/database-schemas.md'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/uml_class.rb',
      'lib/slim_graph_r/layout/uml_class.rb',
      'lib/slim_graph_r/uml_class_svg.rb',
      'examples/standalone/uml_class.rb',
      'examples/standalone/uml_class.json',
      'examples/stream_weaver/uml_classes.rb',
      'docs/uml-classes.md',
      'docs/roadmap/parity-manifest.json'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/quadrant.rb',
      'lib/slim_graph_r/layout/quadrant.rb',
      'lib/slim_graph_r/quadrant_svg.rb',
      'examples/standalone/quadrant.rb',
      'examples/standalone/quadrant.json',
      'examples/stream_weaver/quadrants.rb',
      'docs/quadrants.md'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/venn.rb',
      'lib/slim_graph_r/layout/venn.rb',
      'lib/slim_graph_r/venn_svg.rb',
      'examples/standalone/venn.rb',
      'examples/standalone/venn.json',
      'examples/stream_weaver/venns.rb',
      'docs/venn.md'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/loop.rb',
      'lib/slim_graph_r/layout/loop.rb',
      'lib/slim_graph_r/loop_svg.rb',
      'examples/standalone/loop.rb',
      'examples/standalone/loop.json',
      'examples/stream_weaver/loops.rb',
      'docs/loops.md'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/fishbone.rb',
      'lib/slim_graph_r/layout/fishbone.rb',
      'lib/slim_graph_r/fishbone_svg.rb',
      'examples/standalone/fishbone.rb',
      'examples/standalone/fishbone.json',
      'examples/stream_weaver/fishbones.rb',
      'docs/fishbones.md'
    )
    expect(specification.files).to include(
      'lib/slim_graph_r/wardley.rb',
      'lib/slim_graph_r/layout/wardley.rb',
      'lib/slim_graph_r/wardley_svg.rb',
      'examples/standalone/wardley.rb',
      'examples/standalone/wardley.json',
      'examples/stream_weaver/wardleys.rb',
      'docs/wardley-maps.md'
    )
    package_check = File.read(File.expand_path('../bin/check-package', __dir__), encoding: 'UTF-8')
    expect(package_check).to include('process gantt kanban journey story_map data_flow dp_integration dp_security_matrix entity_relationships database_schema',
                                     "'examples', 'standalone', 'dp_security_matrix.json'",
                                     'data-sgr-dp-security-matrix',
                                     "'examples', 'standalone', 'entity_relationships.json'",
                                     'data-er-cardinality',
                                     "'examples', 'standalone', 'database_schema.json'",
      'data-sgr-db-schema-diagram',
      'uml_class',
      "'examples', 'standalone', 'uml_class.json'",
      'data-sgr-uml-class',
      'quadrant',
      "'examples', 'standalone', 'quadrant.json'",
      'data-sgr-quadrant',
      'venn',
      "'examples', 'standalone', 'venn.json'",
      'data-sgr-venn',
      'loop',
      "'examples', 'standalone', 'loop.json'",
      'data-sgr-loop',
      'fishbone',
      "'examples', 'standalone', 'fishbone.json'",
      'data-sgr-fishbone',
      'wardley',
      "'examples', 'standalone', 'wardley.json'",
      'data-sgr-wardley',
      'bar line scatter treemap sankey',
      'data-sgr-display-scale="1.143"',
      'bar-charts',
      'line-charts',
      'scatter-plots',
      'treemaps',
      'sankeys')
  end
end
