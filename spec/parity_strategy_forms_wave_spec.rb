# frozen_string_literal: true
require 'json'
require 'open3'
require 'tmpdir'
require_relative 'spec_helper'
require_relative '../examples/parity/layers_osi_stack'
require_relative '../examples/parity/pyramid_conversion_funnel'
require_relative '../examples/parity/medallion_survey_architecture'
require_relative '../examples/parity/swimlane_release_workflow'

RSpec.describe 'Layers, Pyramid, Medallion, and Swimlane parity batches' do
  ROOT_FORMS = File.expand_path('..', __dir__)
  TYPES_FORMS = %w[layers pyramid medallion swimlane].freeze

  it 'exposes actionable exact-or-unavailable reasons for each pinned composition' do
    fixtures = [ParityFixtures::LayersOsiStack, ParityFixtures::PyramidConversionFunnel, ParityFixtures::MedallionSurveyArchitecture]
    fixtures.each { |fixture| expect { fixture.diagram }.to raise_error(ArgumentError, /unavailable/) }
    swimlane = ParityFixtures::SwimlaneReleaseWorkflow.diagram
    expect([swimlane.workflow_lanes.size, swimlane.workflow_stages.size, swimlane.workflow_handoffs.size]).to eq([4, 7, 6])
  end

  it 'maps all twelve records and keeps every minimal variant unavailable' do
    registry = JSON.parse(File.read(File.join(ROOT_FORMS, 'docs/roadmap/parity-harness-fixtures.json')))
    fixtures = registry.fetch('fixtures').to_h { |f| [f.fetch('id'), f] }
    TYPES_FORMS.each do |type|
      batch = JSON.parse(File.read(File.join(ROOT_FORMS, "docs/roadmap/parity-batches/#{type}.json")))
      expect(batch.fetch('cases').size).to eq(3)
      batch.fetch('cases').each do |item|
        variant = fixtures.fetch(item.fetch('local_fixture')).fetch('variants').fetch(item.fetch('local_variant'))
        expect(variant.fetch('status')).to eq(item.fetch('local_render'))
      end
      expect(batch.fetch('cases').first(2).map { |item| item.fetch('local_render') }).to eq(batch.fetch('cases').first(2).map { |item| fixtures.fetch(item.fetch('local_fixture')).fetch('variants').fetch(item.fetch('local_variant')).fetch('status') })
    end
  end

  it 'dispatches the four unavailable batches through the CLI without editorial substitution' do
    TYPES_FORMS.each do |type|
      Dir.mktmpdir do |directory|
        output, status = Open3.capture2e(File.join(ROOT_FORMS, 'bin/audit-parity-batch'), type, '--render-only', '--output-root', directory)
        expect(status).to be_success, output
      end
    end
  end
end
