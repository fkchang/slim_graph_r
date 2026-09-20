# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'
require_relative 'spec_helper'
require_relative '../examples/parity/org_chart_agent_team'
require_relative '../examples/parity/state_article_lifecycle'
require_relative '../examples/parity/dependency_typescript_monorepo'
require_relative '../examples/parity/deployment_checkout_service'

RSpec.describe 'Org chart, State, Dependency, and Deployment parity batches' do
  PARITY_HIERARCHY_ROOT = File.expand_path('..', __dir__)
  it 'preserves Deployment payload semantics and records exactness blockers for the other editorial cases' do
    org_chart = ParityFixtures::OrgChartAgentTeam.diagram
    expect(org_chart.nodes.map(&:label)).to include('Athena', 'Growth', 'Hermes')
    expect(org_chart.description).to include('setup gaps visible')

    state = ParityFixtures::StateArticleLifecycle.diagram
    expect(state.states.map(&:label)).to eq(['Draft', 'In Review', 'Published', 'Archived'])
    expect(state.transitions.map { |transition| [transition.from, transition.to, transition.label] }).to include(['in_review', 'draft', 'reject · revise'])

    dependency = ParityFixtures::DependencyTypescriptMonorepo.diagram
    expect(dependency.layout.routes.size).to eq(12)

    deployment = ParityFixtures::DeploymentCheckoutService.diagram
    expect(deployment.zones.map(&:label)).to eq(['Edge', 'Prod / eu-west-1', 'Data'])
    expect(deployment.nodes.find { |node| node.id == 'app' }.replicas).to eq(3)
    expect(deployment.edges.map { |edge| [edge.from, edge.to, edge.label, edge.dashed] }).to eq([
      ['cloudflare', 'ingress', 'HTTPS:443', false],
      ['ingress', 'app', 'HTTP:8080', false],
      ['app', 'rds_primary', 'TLS:5432', false],
      ['rds_primary', 'rds_standby', 'WAL STREAM:5432', true]
    ])
  end

  it 'keeps the exact dependency fixture complete rather than silently reducing its graph' do
    source = File.read(File.join(PARITY_HIERARCHY_ROOT, 'examples/parity/dependency_typescript_monorepo.rb'))

    expect(source.scan(/^\s*dependency |^\s*external_dependency /).size).to eq(9)
    expect(source.scan(/^\s*depends_on /).size).to eq(12)
    expect(source).to include('depends_on :utils, :shared_types, cycle: true')
    expect(source).to include('depends_on :db, :shared_types')
    expect(source).to include('depends_on :ui_kit, :tokens')
  end

  it 'keeps the org-chart editorial fixture renderable while its browser gate is pending' do
    html = ParityFixtures::OrgChartAgentTeam.diagram.to_html

    expect(html).to include('SETUP GAP', 'Slack bot invitation is still missing', 'Production approval gate needs a named owner')
  end

  it 'maps all twelve cases to explicit registry statuses and only dispatches an exact editorial counterpart' do
    registry = JSON.parse(File.read(File.join(PARITY_HIERARCHY_ROOT, 'docs/roadmap/parity-harness-fixtures.json')))
    fixtures = registry.fetch('fixtures').to_h { |fixture| [fixture.fetch('id'), fixture] }
    index = JSON.parse(File.read(File.join(PARITY_HIERARCHY_ROOT, 'docs/roadmap/parity-fixtures-v0.json')))

    %w[org-chart state dependency deployment].each do |type|
      batch = JSON.parse(File.read(File.join(PARITY_HIERARCHY_ROOT, "docs/roadmap/parity-batches/#{type}.json")))
      expect(batch.fetch('cases').map { |item| item.fetch('baseline_case_id') }).to eq(["#{type}:minimal-light", "#{type}:minimal-dark", "#{type}:full-editorial"])
      batch.fetch('cases').each do |item|
        variant = fixtures.fetch(item.fetch('local_fixture')).fetch('variants').fetch(item.fetch('local_variant'))
        expect(variant.fetch('status')).to eq(item.fetch('local_render'))
        expect(index.fetch('records').count { |record| record.fetch('baseline_case_id') == item.fetch('baseline_case_id') }).to eq(1)
      end
    end

    Dir.mktmpdir do |directory|
      %w[org-chart state dependency deployment].each do |type|
        output, status = Open3.capture2e(File.join(PARITY_HIERARCHY_ROOT, 'bin/audit-parity-batch'), type, '--render-only', '--output-root', File.join(directory, type))
        expect(status).to be_success, output
      end
      org_path = File.join(directory, 'org-chart', 'generated', 'org-chart__full-editorial.html')
      expect(File).to exist(org_path)
      expect(File.read(org_path, encoding: 'UTF-8')).to include('Agent team responsibility map')
      expect(Dir.glob(File.join(directory, 'org-chart', 'generated', '*.html')).sort).to eq([org_path, File.join(directory, 'org-chart', 'generated', 'org-chart__minimal-dark.html'), File.join(directory, 'org-chart', 'generated', 'org-chart__minimal-light.html')].sort)
      expect(File).to exist(File.join(directory, 'state', 'generated', 'state__full-editorial.html'))
      expect(File).to exist(File.join(directory, 'dependency', 'generated', 'dependency__full-editorial.html'))
      expect(File).to exist(File.join(directory, 'deployment', 'generated', 'deployment__full-editorial.html'))
    end
  end

end
