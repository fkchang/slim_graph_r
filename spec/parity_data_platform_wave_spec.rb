# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'
require_relative 'spec_helper'
require_relative '../examples/parity/story_map_reporting'
require_relative '../examples/parity/data_flow_reporting'
require_relative '../examples/parity/dp_integration_platform'
require_relative '../examples/parity/dp_security_matrix_platform'

RSpec.describe 'Story map and data-platform parity batches' do
  ROOT_DATA_PLATFORM = File.expand_path('..', __dir__)
  TYPES_DATA_PLATFORM = %w[story-map data-flow dp-integration dp-security-matrix].freeze

  it 'preserves the exact pinned Story map payload' do
    diagram = ParityFixtures::StoryMapReporting.diagram

    expect(diagram.persona).to eq('Reporting analyst')
    expect(diagram.story_activities.map { |activity| [activity.id, activity.label, activity.steps.map { |step| [step.id, step.label] }] }).to eq([
      ['find', 'Find the data', [['search', 'Search datasets'], ['preview', 'Preview rows']]],
      ['build', 'Build the report', [['columns', 'Pick columns'], ['chart', 'Add a chart']]],
      ['share', 'Share it', [['link', 'Send a link']]],
      ['trust', 'Trust it', [['freshness', 'Check freshness']]]
    ])
    expect(diagram.story_releases.map { |release| [release.id, release.label, release.cut] }).to eq([
      ['mvp', 'MVP', true], ['release_2', 'Release 2', false], ['later', 'Later', false]
    ])
    expect(diagram.story_releases.flat_map(&:stories).map { |story| [story.id, story.label, story.activity, story.ticket, story.estimate, story.risk] }).to eq([
      ['keyword', 'Keyword search', 'find', 'RPT-101', '3pt', false],
      ['table_chart', 'Table + one chart', 'build', 'RPT-102', '5pt', false],
      ['public_link', 'Public link', 'share', 'RPT-103', '2pt', false],
      ['updated', 'Last-updated stamp', 'trust', 'RPT-104', '1pt', false],
      ['filters', 'Saved filters', 'find', 'RPT-110', '3pt', false],
      ['email', 'Scheduled email', 'share', 'RPT-112', '5pt', false],
      ['permissions', 'Row-level permissions', 'trust', 'RPT-114', '3pt', true],
      ['natural_language', 'Natural-language query', 'find', 'RPT-120', '8pt', false],
      ['alerts', 'Alerting on anomalies', 'trust', 'RPT-121', '5pt', false]
    ])
  end

  it 'preserves Data flow transfer details in the exact editorial fixture' do
    diagram = ParityFixtures::DataFlowReporting.diagram
    expect(diagram.data_flow_transfers.map(&:detail)).to include('shop events → batch', 'raw → trusted table')

    scene = diagram.layout
    curate = scene.cards.find { |card| card[:transfer].id == 'curate' }
    analyze = scene.steps.find { |step| step[:step].id == 'analyze' }
    expected_width = SlimGraphR::Text.grid(SlimGraphR::Text.width('conversion · revenue', 12, font: :mono) + 16)
    expect(curate[:width]).to eq(expected_width)
    expect(analyze[:width]).to be >= curate[:width] + 2 * SlimGraphR::Layout::DataFlow::CARD_INSET
    expect(scene.steps.map { |step| step[:step].id }).to eq(%w[ingest store transform analyze publish])
    expect(diagram.to_svg(id: 'reporting-data-flow')).to include('conversion · revenue', 'data-sgr-transfer="curate"')

    source = File.read(File.join(ROOT_DATA_PLATFORM, 'examples/parity/data_flow_reporting.rb'), encoding: 'UTF-8')
    expect(source).to include(
      "detail: 'shop events → batch'", "detail: 'events · orders'", "detail: 'raw → trusted table'",
      "detail: 'conversion · revenue'", "detail: 'metrics → decisions'"
    )
  end

  it 'preserves the exact pinned DP integration payload in measured card and route lanes' do
    diagram = ParityFixtures::DPIntegrationPlatform.diagram

    expect(diagram.integration_sources.map { |item| [item.id, item.label, item.kind, item.detail] }).to eq([
      ['crm', 'CRM', :database, 'customer records'],
      ['pos_exports', 'POS exports', :file_drop, 'daily CSV batches'],
      ['event_stream', 'Event stream', :legacy, 'near-real-time events']
    ])
    expect(diagram.integration_platform.label).to eq('Data platform')
    expect(diagram.integration_platform.bands.flat_map(&:items).map { |item| [item.id, item.label, item.role, item.detail, item.focal, item.serves, item.band_kind] }).to eq([
      ['orchestrator', 'Orchestrator', 'DAG', 'schedules · retries · lineage', false, false, :bar],
      ['object_storage', 'Object storage', 'STORE', 'versioned data objects', true, false, :row],
      ['query_engine', 'Query engine', 'SQL', 'federated SQL access', true, true, :row]
    ])
    expect(diagram.integration_consumers.map { |item| [item.id, item.label, item.kind, item.detail] }).to eq([
      ['bi_tool', 'BI tool', :analytics, 'dashboards · reports'],
      ['notebooks', 'Notebooks', :analytics, 'Python · exploration'],
      ['partner_api', 'Partner API', :api, 'scoped data products']
    ])
    expect(diagram.integration_layer_services.map { |item| [item.label, item.kind, item.detail, item.protocol] }).to eq([
      ['Identity provider', :identity, 'SSO · service identities · policy groups', 'AUTH'],
      ['Centralized logging', :observability, 'platform events · audit trail · retention', 'AUTH']
    ])
    expect(diagram.integration_wires.map { |wire| [wire.from, wire.to, wire.kind, wire.protocol] }).to eq([
      ['crm', 'object_storage', :ordinary, 'REST'], ['pos_exports', 'object_storage', :ordinary, 'CSV'],
      ['event_stream', 'object_storage', :ordinary, 'EVENTS'], ['orchestrator', 'object_storage', :trigger, nil],
      ['object_storage', 'query_engine', :federated, 'READ'], ['query_engine', 'bi_tool', :serve, 'JDBC'],
      ['query_engine', 'notebooks', :serve, 'KERNEL'], ['query_engine', 'partner_api', :serve, 'HTTPS']
    ])
    scene = diagram.layout
    expect(scene.side_cards.select { |entry| entry[:side] == :source }.map { |entry| entry[:width] }).to all(eq(208))
    expect(scene.routes.find { |entry| entry[:wire].protocol == 'CSV' }[:label][:rect]).to eq([279.0, 189.0, 319.0, 203.0])
    expect(diagram.to_svg).to include('customer records')
  end

  it 'preserves every pinned DP security-matrix coordinate and focal claim' do
    diagram = ParityFixtures::DPSecurityMatrixPlatform.diagram
    expect(diagram.security_roles.map { |role| [role.id, role.label, role.code] }).to eq([
      ['engineer', 'Data Engineer', 'GRP-DATA-ENG'], ['scientist', 'Data Scientist', 'GRP-DATA-SCI'],
      ['analyst', 'Analyst', 'GRP-ANALYST'], ['administrator', 'Administrator', 'GRP-ADMIN'],
      ['partner', 'External Partner', 'GRP-PARTNER']
    ])
    expect(diagram.security_components.map { |component| [component.id, component.label, component.hint] }).to eq([
      ['storage', 'Object storage', 'S3'], ['query', 'Query engine', 'SQL'], ['notebooks', 'Notebooks', 'PY'],
      ['bi', 'BI tool', 'DASH'], ['orchestrator', 'Orchestrator', 'DAG']
    ])
    expected_levels = {
      storage: %i[write read deny admin deny], query: %i[write read read admin read],
      notebooks: %i[write write deny admin deny], bi: %i[write read write admin read],
      orchestrator: %i[write read deny admin deny]
    }
    expect(diagram.security_permissions.map(&:level)).to eq(expected_levels.values.flatten)
    focal = diagram.security_permissions.find(&:focal)
    expect([focal.component, focal.role, focal.label, focal.level, focal.note]).to eq(['bi', 'partner', 'Read', :read, 'shared dashboards'])
    expect(diagram.to_svg).to include('shared dashboards')
  end

  it 'maps all twelve cases, dispatches exact captures, and reports every unavailable reason' do
    registry = JSON.parse(File.read(File.join(ROOT_DATA_PLATFORM, 'docs/roadmap/parity-harness-fixtures.json'), encoding: 'UTF-8'))
    fixtures = registry.fetch('fixtures').to_h { |fixture| [fixture.fetch('id'), fixture] }
    index = JSON.parse(File.read(File.join(ROOT_DATA_PLATFORM, 'docs/roadmap/parity-fixtures-v0.json'), encoding: 'UTF-8'))

    TYPES_DATA_PLATFORM.each do |type|
      batch = JSON.parse(File.read(File.join(ROOT_DATA_PLATFORM, "docs/roadmap/parity-batches/#{type}.json"), encoding: 'UTF-8'))
      expect(batch.fetch('cases').map { |item| item.fetch('baseline_case_id') }).to eq(["#{type}:minimal-light", "#{type}:minimal-dark", "#{type}:full-editorial"])
      batch.fetch('cases').each do |item|
        variant = fixtures.fetch(item.fetch('local_fixture')).fetch('variants').fetch(item.fetch('local_variant'))
        expect(variant.fetch('status')).to eq(item.fetch('local_render'))
        expect(index.fetch('records').count { |record| record.fetch('baseline_case_id') == item.fetch('baseline_case_id') }).to eq(1)
      end
    end

    Dir.mktmpdir do |directory|
      TYPES_DATA_PLATFORM.each do |type|
        output, status = Open3.capture2e(File.join(ROOT_DATA_PLATFORM, 'bin/audit-parity-batch'), type, '--render-only', '--output-root', File.join(directory, type))
        expect(status).to be_success, output
      end
      expect(File).to exist(File.join(directory, 'story-map', 'generated', 'story-map__full-editorial.html'))
      expect(File).to exist(File.join(directory, 'dp-security-matrix', 'generated', 'dp-security-matrix__full-editorial.html'))
      expect(File).to exist(File.join(directory, 'data-flow', 'generated', 'data-flow__full-editorial.html'))
      expect(File).to exist(File.join(directory, 'dp-integration', 'generated', 'dp-integration__full-editorial.html'))
    end

    output, status = Open3.capture2e(File.join(ROOT_DATA_PLATFORM, 'bin/render-parity-fixture'), 'dp-integration-platform', '--variant', 'full-editorial', '--output', '/tmp/ignored.html')
    expect(status).to be_success, output
    expect(File.read('/tmp/ignored.html')).to include('customer records')
    TYPES_DATA_PLATFORM.each do |type|
      fixture = JSON.parse(File.read(File.join(ROOT_DATA_PLATFORM, "docs/roadmap/parity-batches/#{type}.json"))).fetch('cases').first.fetch('local_fixture')
      output, status = Open3.capture2e(File.join(ROOT_DATA_PLATFORM, 'bin/render-parity-fixture'), fixture, '--variant', 'minimal-light', '--output', '/tmp/ignored.html')
      if index.fetch('records').find { |record| record.fetch('baseline_case_id') == "#{type}:minimal-light" }.dig('audit', 'classification') == 'supported-unverified'
        expect(status).to be_success, output
        expect(File.read('/tmp/ignored.html')).to include('data-sgr-style="minimal"', 'data-sgr-theme="light"')
      else
        expect(status).not_to be_success
        expect(output).to include('SlimGraphR has no minimal profile; do not substitute editorial.')
      end
    end
  end
end
