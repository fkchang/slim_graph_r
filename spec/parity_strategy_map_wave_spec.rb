# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'
require_relative 'spec_helper'
require_relative '../examples/parity/venn_product_fit'
require_relative '../examples/parity/loop_self_improving'
require_relative '../examples/parity/fishbone_checkout_latency'
require_relative '../examples/parity/wardley_ai_value_chain'

RSpec.describe 'Venn, Loop, Fishbone, and Wardley parity batches' do
  ROOT_STRATEGY_MAP = File.expand_path('..', __dir__)
  TYPES_STRATEGY_MAP = %w[venn loop fishbone wardley].freeze
  it 'retains every exact pinned input and raises its measured or semantic blocker' do
    expect(ParityFixtures::VennProductFit.diagram.venn_sets.map(&:subtitle)).to include('PEOPLE WANT IT', 'WE CAN BUILD IT', 'BUSINESS SUSTAINS')
    loop = ParityFixtures::LoopSelfImproving.diagram
    expect(loop.layout.station_boxes.map(&:width)).to all(eq(164))
    expect(loop.to_svg).to include('signals in / intake')
    expect(ParityFixtures::FishboneCheckoutLatency.diagram.fishbone_categories.find(&:confirmed).label).to eq('DATA')
    wardley = ParityFixtures::WardleyAIValueChain.diagram.to_svg(id: 'wardley-editorial')
    expect(wardley.scan('data-sgr-wardley-dependency=').size).to eq(7)
    expect(wardley.scan(/data-sgr-hops="(\d+)"/).flatten.map(&:to_i).sum).to be >= 1
  end

  it 'maps all twelve cases to their pinned index records and unavailable registry statuses' do
    registry = JSON.parse(File.read(File.join(ROOT_STRATEGY_MAP, 'docs/roadmap/parity-harness-fixtures.json'), encoding: 'UTF-8'))
    fixtures = registry.fetch('fixtures').to_h { |fixture| [fixture.fetch('id'), fixture] }
    index = JSON.parse(File.read(File.join(ROOT_STRATEGY_MAP, 'docs/roadmap/parity-fixtures-v0.json'), encoding: 'UTF-8'))
    manifest = JSON.parse(File.read(File.join(ROOT_STRATEGY_MAP, 'docs/roadmap/parity-manifest.json'), encoding: 'UTF-8'))

    TYPES_STRATEGY_MAP.each do |type|
      batch = JSON.parse(File.read(File.join(ROOT_STRATEGY_MAP, "docs/roadmap/parity-batches/#{type}.json"), encoding: 'UTF-8'))
      expect(batch.fetch('cases').map { |item| item.fetch('baseline_case_id') }).to eq(["#{type}:minimal-light", "#{type}:minimal-dark", "#{type}:full-editorial"])
      batch.fetch('cases').each do |item|
        fixture = fixtures.fetch(item.fetch('local_fixture'))
        variant = fixture.fetch('variants').fetch(item.fetch('local_variant'))
        record = index.fetch('records').find { |candidate| candidate.fetch('baseline_case_id') == item.fetch('baseline_case_id') }
        manifest_type = manifest.fetch('types').find { |candidate| candidate.fetch('type') == type }

        expected_status = item.fetch('local_render')
        expect(variant.fetch('status')).to eq(expected_status)
        expect(item.fetch('local_render')).to eq(expected_status)
        expect(record.dig('local_render', 'variant')).to eq(item.fetch('local_variant'))
        expect(record.dig('audit', 'classification')).to eq(manifest_type.dig('baseline_case_status', item.fetch('local_variant'), 'classification'))
      end
      expected_classification = 'supported-unverified'
      expect(manifest.fetch('types').find { |candidate| candidate.fetch('type') == type }
                     .dig('baseline_case_status', 'full-editorial', 'classification')).to eq(expected_classification)
    end
  end

  it 'dispatches no reduced substitute and returns each editorial reason through the registry' do
    Dir.mktmpdir do |directory|
      TYPES_STRATEGY_MAP.each do |type|
        output, status = Open3.capture2e(File.join(ROOT_STRATEGY_MAP, 'bin/audit-parity-batch'), type, '--render-only', '--output-root', File.join(directory, type))
        expect(status).to be_success, output
        rendered = Dir[File.join(directory, type, 'generated', '*.html')]
        if TYPES_STRATEGY_MAP.include?(type)
          expect(rendered).to include(File.join(directory, type, 'generated', "#{type}__full-editorial.html"))
        else
          expect(rendered).to be_empty
        end
      end
    end
  end
end
