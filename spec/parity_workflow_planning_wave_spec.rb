# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'
require_relative 'spec_helper'
require_relative '../examples/parity/process_survey_build'
require_relative '../examples/parity/gantt_platform_launch'
require_relative '../examples/parity/kanban_platform_team'
require_relative '../examples/parity/journey_trial_paid'

RSpec.describe 'Process, Gantt, Kanban, and Journey parity batches' do
  ROOT_WORKFLOW = File.expand_path('..', __dir__)
  TYPES_WORKFLOW = %w[process gantt kanban journey].freeze

  it 'models the pinned Process lanes, stages, tools, payloads, and handoffs' do
    diagram = ParityFixtures::ProcessSurveyBuild.diagram

    expect(diagram.workflow_lanes.map { |lane| [lane.id, lane.label, lane.key] }).to eq([
      ['customer', 'Customer', 'CUS'], ['support', 'Support', 'SUP'], ['warehouse', 'Warehouse', 'WHS'], ['finance', 'Finance', 'FIN']
    ])
    expect(diagram.workflow_stages.map { |stage| [stage.id, stage.label, stage.focal] }).to eq([
      ['order', 'Order', false], ['verify', 'Verify', false], ['allocate', 'Allocate', true], ['pick', 'Pick', false],
      ['pack', 'Pack', false], ['pay', 'Pay', false], ['receive', 'Receive', false], ['close', 'Close', false]
    ])
    expect(diagram.operations.map { |operation| [operation.id, operation.lane, operation.stage, operation.tool, operation.input, operation.output, operation.focal] }).to eq([
      ['place_order', 'customer', 'order', 'storefront', nil, 'DB', false],
      ['verify_order', 'support', 'verify', 'service desk', 'DB', 'DB', false],
      ['allocate_stock', 'warehouse', 'allocate', 'inventory system', 'DB', 'LS', true],
      ['pick_items', 'warehouse', 'pick', 'handheld scanner', 'LS', 'LS', false],
      ['pack_order', 'warehouse', 'pack', 'packing station', 'LS', 'FL', false],
      ['capture_payment', 'finance', 'pay', 'payment gateway', 'FL', 'TB', false],
      ['receive_shipment', 'customer', 'receive', 'delivery portal', 'TB', 'WB', false],
      ['close_order', 'support', 'close', 'service desk', 'WB', nil, false]
    ])
    expect(diagram.workflow_handoffs.map { |handoff| [handoff.from, handoff.to] }).to eq([
      %w[place_order verify_order], %w[verify_order allocate_stock], %w[allocate_stock pick_items], %w[pick_items pack_order],
      %w[pack_order capture_payment], %w[capture_payment receive_shipment], %w[receive_shipment close_order]
    ])
  end

  it 'models the pinned Gantt phases/calendar tasks and Kanban WIP/state census' do
    gantt = ParityFixtures::GanttPlatformLaunch.diagram
    expect(gantt.gantt_phases.map(&:label)).to eq(%w[Discovery Design Launch])
    expect(gantt.gantt_tasks.map { |task| [task.label, task.start, task.finish, task.focal] }).to eq([
      ['Market research', '2026-04-06', '2026-04-20', false], ['User interviews', '2026-04-13', '2026-04-27', false],
      ['Wireframes', '2026-04-27', '2026-05-11', false], ['Prototype', '2026-05-04', '2026-05-25', false],
      ['Design review', '2026-05-25', '2026-06-01', true], ['Development', '2026-05-18', '2026-06-15', false],
      ['Beta testing', '2026-06-08', '2026-06-22', false]
    ])
    expect(gantt.gantt_milestones).to be_empty
    expect(gantt.gantt_markers).to be_empty

    kanban = ParityFixtures::KanbanPlatformTeam.diagram
    expect(kanban.kanban_columns.map { |column| [column.label, column.wip_limit, column.cards.size] }).to eq([
      ['Backlog', nil, 3], ['In progress', 3, 4], ['Review', 3, 2], ['Done', nil, 2]
    ])
    expect(kanban.kanban_columns.flat_map(&:cards).map { |card| [card.id, card.state] }).to include(
      ['postgres_upgrade', :blocked], ['vendor_sso', :waiting], ['retention', :done], ['rate_limiting', :default]
    )
  end

  it 'renders the complete Journey pain marker in its measured expanded stage cell' do
    journey = ParityFixtures::JourneyTrialPaid.diagram
    expect(journey.journey_stages.map { |stage| [stage.label, stage.sentiment, stage.action, stage.touchpoint, stage.pains] }).to eq([
      ['Sign up', :high, 'Create workspace', 'signup form', []],
      ['First run', :neutral, 'Import first dataset', 'onboarding wizard', []],
      ['Invite team', :high, 'Add 3 teammates', 'email invite', []],
      ['Hit the limit', :low, 'Export blocked mid-report', 'in-app modal', ['NO WARNING AT 80%', 'PRICING PAGE IS 3 CLICKS AWAY']],
      ['Upgrade', :neutral, 'Pick annual plan', 'billing page', []]
    ])
    scene = journey.layout
    pain = scene.pains.find { |entry| entry[:value] == 'PRICING PAGE IS 3 CLICKS AWAY' }
    expect([pain[:width], scene.headers.find { |entry| entry[:stage].id == 'hit_limit' }[:width]]).to eq([244, 260])
    expect(journey.to_svg).to include('PRICING PAGE IS 3 CLICKS AWAY')
  end

  it 'maps all twelve cases and dispatches only exact editorial fixtures' do
    registry = JSON.parse(File.read(File.join(ROOT_WORKFLOW, 'docs/roadmap/parity-harness-fixtures.json')))
    fixtures = registry.fetch('fixtures').to_h { |fixture| [fixture.fetch('id'), fixture] }
    TYPES_WORKFLOW.each do |type|
      batch = JSON.parse(File.read(File.join(ROOT_WORKFLOW, "docs/roadmap/parity-batches/#{type}.json")))
      expect(batch.fetch('cases').map { |item| item.fetch('baseline_case_id') }).to eq(["#{type}:minimal-light", "#{type}:minimal-dark", "#{type}:full-editorial"])
      batch.fetch('cases').each do |item|
        expect(fixtures.fetch(item.fetch('local_fixture')).fetch('variants').fetch(item.fetch('local_variant')).fetch('status')).to eq(item.fetch('local_render'))
      end
    end
    Dir.mktmpdir do |directory|
      TYPES_WORKFLOW.each do |type|
        output, status = Open3.capture2e(File.join(ROOT_WORKFLOW, 'bin/audit-parity-batch'), type, '--render-only', '--output-root', File.join(directory, type))
        expect(status).to be_success, output
      end
      %w[process gantt kanban journey].each { |type| expect(File).to exist(File.join(directory, type, 'generated', "#{type}__full-editorial.html")) }
    end
  end

  it 'renders the measured Journey editorial fixture through the registry' do
    output, status = Open3.capture2e(File.join(ROOT_WORKFLOW, 'bin/render-parity-fixture'), 'journey-trial-paid', '--variant', 'full-editorial', '--output', '/tmp/ignored.html')
    expect(status).to be_success, output
    expect(File.read('/tmp/ignored.html')).to include('PRICING PAGE IS 3 CLICKS AWAY')
  end
end
