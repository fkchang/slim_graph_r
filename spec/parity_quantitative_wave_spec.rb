# frozen_string_literal: true

require 'digest'
require 'json'
require 'open3'
require 'tmpdir'
require_relative 'spec_helper'
require_relative '../examples/parity/bar_sprint_velocity'
require_relative '../examples/parity/line_weekly_signups'
require_relative '../examples/parity/scatter_deploy_frequency'
require_relative '../examples/parity/radar_storage_backends'
require_relative '../examples/parity/polar_request_demand'
require_relative '../examples/parity/treemap_world_population'
require_relative '../examples/parity/sankey_ci_budget'

RSpec.describe 'Quantitative parity batches' do
  ROOT_QUANTITATIVE = File.expand_path('..', __dir__)
  TYPES_QUANTITATIVE = %w[bar line scatter radar polar treemap sankey].freeze
  FIXTURES_QUANTITATIVE = {
    'bar' => ['bar-sprint-velocity', 'examples/parity/bar_sprint_velocity.rb'],
    'line' => ['line-weekly-signups', 'examples/parity/line_weekly_signups.rb'],
    'scatter' => ['scatter-deploy-frequency', 'examples/parity/scatter_deploy_frequency.rb'],
    'radar' => ['radar-storage-backends', 'examples/parity/radar_storage_backends.rb'],
    'polar' => ['polar-request-demand', 'examples/parity/polar_request_demand.rb'],
    'treemap' => ['treemap-world-population', 'examples/parity/treemap_world_population.rb'],
    'sankey' => ['sankey-ci-budget', 'examples/parity/sankey_ci_budget.rb']
  }.freeze

  def values(records)
    records.map { |record| record.value.to_f }
  end

  it 'preserves the exact Bar, Line, Radar, Polar, and Treemap payloads' do
    bar = ParityFixtures::BarSprintVelocity.diagram
    expect(bar.categories.map { |item| [item.label, item.value.to_i, item.focal] }).to eq([
      ['S1', 72, false], ['S2', 88, false], ['S3', 95, false], ['S4', 78, false],
      ['S5', 110, true], ['S6', 102, false], ['S7', 85, false], ['S8', 93, false]
    ])

    line = ParityFixtures::LineWeeklySignups.diagram
    expect(line.x_domain).to eq(%w[W1 W2 W3 W4 W5 W6 W7 W8])
    expect(line.series_list.map { |series| [series.id, values(series.observations), series.focal] }).to eq([
      ['organic', [120, 135, 148, 162, 155, 178, 195, 210], true],
      ['direct', [80, 82, 88, 90, 86, 92, 95, 98], false],
      ['referral', [45, 52, 48, 60, 55, 68, 62, 75], false]
    ])

    radar = ParityFixtures::RadarStorageBackends.diagram
    expect(radar.criteria.map(&:label)).to eq(['Small-file handling', 'Large-object reads', 'Write throughput', 'Operational simplicity', 'Iceberg integration'])
    expect(radar.entities.map { |entity| [entity.label, entity.values.values.map(&:to_i), entity.focal] }).to eq([
      ['MinIO', [9, 8, 9, 9, 9], true], ['Amazon S3', [6, 10, 9, 5, 8], false],
      ['Ceph', [7, 7, 7, 4, 6], false], ['Google Cloud Storage', [6, 9, 8, 6, 7], false]
    ])

    polar = ParityFixtures::PolarRequestDemand.diagram
    expect(polar.categories.map { |item| [item.label, item.value.to_i, item.focal] }).to eq([
      ['00–03', 32, false], ['03–06', 18, false], ['06–09', 24, false], ['09–12', 58, false],
      ['12–15', 100, true], ['15–18', 82, false], ['18–21', 76, false], ['21–24', 45, false]
    ])

    treemap = ParityFixtures::TreemapWorldPopulation.diagram
    expect(treemap.items.map { |item| [item.label, item.value.to_f, item.focal] }).to eq([
      ['Asia', 4.78, true], ['Africa', 1.48, false], ['Europe', 0.75, false],
      ['North America', 0.61, false], ['South America', 0.43, false], ['Oceania', 0.05, false]
    ])
  end

  it 'preserves anonymous scatter marks and focal Sankey ribbons without invented identities' do
    scatter = ParityFixtures::ScatterDeployFrequency.diagram
    expect(scatter.points.count(&:anonymous)).to eq(11)
    expect(scatter.points.find(&:focal).label).to eq('Platform')
    expect(scatter.to_svg(id: 'scatter-parity')).to include('data-anonymous-point="true"')
    sankey = ParityFixtures::SankeyCIBudget.diagram
    expect(sankey.flows.count(&:focal)).to eq(2)
    expect(sankey.to_svg(id: 'sankey-parity')).to include('data-sankey-legend="true"', 'data-focal="true"')
  end

  it 'maps all 21 cases by baseline ID without mutating an earlier record' do
    index = JSON.parse(File.read(File.join(ROOT_QUANTITATIVE, 'docs/roadmap/parity-fixtures-v0.json'), encoding: 'UTF-8'))
    manifest = JSON.parse(File.read(File.join(ROOT_QUANTITATIVE, 'docs/roadmap/parity-manifest.json'), encoding: 'UTF-8'))
    registry = JSON.parse(File.read(File.join(ROOT_QUANTITATIVE, 'docs/roadmap/parity-harness-fixtures.json'), encoding: 'UTF-8'))
    records = index.fetch('records').to_h { |record| [record.fetch('baseline_case_id'), record] }
    fixtures = registry.fetch('fixtures').to_h { |fixture| [fixture.fetch('id'), fixture] }

    TYPES_QUANTITATIVE.each do |type|
      fixture_id, fixture_path = FIXTURES_QUANTITATIVE.fetch(type)
      batch = JSON.parse(File.read(File.join(ROOT_QUANTITATIVE, "docs/roadmap/parity-batches/#{type}.json"), encoding: 'UTF-8'))
      manifest_type = manifest.fetch('types').find { |candidate| candidate.fetch('type') == type }
      expect(batch.fetch('cases').map { |item| item.fetch('baseline_case_id') }).to eq(
        ["#{type}:minimal-light", "#{type}:minimal-dark", "#{type}:full-editorial"]
      )
      batch.fetch('cases').each do |item|
        record = records.fetch(item.fetch('baseline_case_id'))
        expect(item.fetch('local_fixture')).to eq(fixture_id)
        expect(record.fetch('type')).to eq(type)
        expect(record.dig('local_semantic_fixture', 'path')).to eq(fixture_path)
        expect(record.dig('local_semantic_fixture', 'sha256')).to eq(Digest::SHA256.file(File.join(ROOT_QUANTITATIVE, fixture_path)).hexdigest)
        expect(fixtures.fetch(fixture_id).dig('variants', item.fetch('local_variant'), 'status')).to eq(item.fetch('local_render'))
        expect(record.dig('audit', 'classification')).to eq(manifest_type.dig('baseline_case_status', item.fetch('local_variant'), 'classification'))
      end
    end

    quantitative_paths = FIXTURES_QUANTITATIVE.values.map(&:last)
    expect(index.fetch('records').reject { |record| TYPES_QUANTITATIVE.include?(record.fetch('type')) }
      .map { |record| record.dig('local_semantic_fixture', 'path') }.compact & quantitative_paths).to be_empty
    expect(records.dig('swimlane:full-editorial', 'local_semantic_fixture', 'path')).to eq('examples/parity/swimlane_release_workflow.rb')
    expect(records.dig('process:full-editorial', 'local_semantic_fixture', 'path')).to eq('examples/parity/process_survey_build.rb')
    expect(records.dig('gantt:full-editorial', 'local_semantic_fixture', 'path')).to eq('examples/parity/gantt_platform_launch.rb')
    expect(records.dig('kanban:full-editorial', 'local_semantic_fixture', 'path')).to eq('examples/parity/kanban_platform_team.rb')
    expect(records.dig('journey:full-editorial', 'local_semantic_fixture', 'path')).to eq('examples/parity/journey_trial_paid.rb')
  end

  it 'renders every configured candidate in render-only mode' do
    Dir.mktmpdir do |directory|
      TYPES_QUANTITATIVE.each do |type|
        output, status = Open3.capture2e(File.join(ROOT_QUANTITATIVE, 'bin/audit-parity-batch'), type, '--render-only', '--output-root', File.join(directory, type))
        expect(status).to be_success, output
      end
      expect(Dir[File.join(directory, '*', 'generated', '*.html')].map { |path| File.basename(path) }.sort).to eq(
        %w[bar__full-editorial.html bar__minimal-dark.html bar__minimal-light.html line__full-editorial.html line__minimal-dark.html line__minimal-light.html polar__full-editorial.html polar__minimal-dark.html polar__minimal-light.html radar__full-editorial.html radar__minimal-dark.html radar__minimal-light.html sankey__full-editorial.html sankey__minimal-dark.html sankey__minimal-light.html scatter__full-editorial.html scatter__minimal-dark.html scatter__minimal-light.html treemap__full-editorial.html treemap__minimal-dark.html treemap__minimal-light.html]
      )
    end
  end
end
