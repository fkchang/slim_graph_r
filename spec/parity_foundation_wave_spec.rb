# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'
require_relative 'spec_helper'
require_relative '../examples/parity/flowchart_skill_decision'
require_relative '../examples/parity/sequence_article_request'
require_relative '../examples/parity/timeline_product_launch'

RSpec.describe 'Flowchart, Sequence, and Timeline parity foundation batches' do
  FOUNDATION_ROOT = File.expand_path('..', __dir__)
  TYPES = %w[flowchart sequence timeline].freeze

  it 'models the pinned Flowchart skill-decision content and labelled branches' do
    diagram = ParityFixtures::FlowchartSkillDecision.diagram

    expect(diagram.title).to eq('Should you write this as a skill?')
    expect(diagram.nodes.map { |node| [node.id, node.kind, node.label, node.detail] }).to eq([
      ['new_workflow', :start, 'New workflow', nil],
      ['manual_once', :service, 'Do it manually once', nil],
      ['repeat', :decision, 'Will you repeat it >3 times?', nil],
      ['one_off', :finish, 'One-off', 'keep manual'],
      ['reusable', :decision, 'Reusable across projects?', nil],
      ['claude_note', :finish, 'CLAUDE.md note', 'project-scoped'],
      ['write_skill', :finish, 'Write a skill', 'reusable + assets']
    ])
    expect(diagram.nodes.select(&:emphasis).map(&:id)).to eq(['write_skill'])
    expect(diagram.edges.map { |edge| [edge.from, edge.to, edge.label] }).to eq([
      ['new_workflow', 'manual_once', nil],
      ['manual_once', 'repeat', nil],
      ['repeat', 'one_off', 'NO'],
      ['repeat', 'reusable', 'YES'],
      ['reusable', 'claude_note', 'NO'],
      ['reusable', 'write_skill', 'YES']
    ])
  end

  it 'models the pinned cold-cache Sequence actors, control flow, and message kinds' do
    diagram = ParityFixtures::SequenceArticleRequest.diagram

    expect(diagram.title).to eq('Article request, cold cache')
    expect(diagram.nodes.map { |node| [node.id, node.kind, node.label, node.detail, node.emphasis] }).to eq([
      ['reader', :external, 'Reader', 'Browser', false],
      ['cloudflare', :service, 'Cloudflare', 'Pages · cache', false],
      ['astro_origin', :service, 'Astro Origin', 'SSR + MDX', true],
      ['analytics', :service, 'Analytics', 'Beacon · async', false]
    ])
    expect(diagram.edges.map { |edge| [edge.from, edge.to, edge.label, edge.kind, edge.dashed] }).to eq([
      ['reader', 'cloudflare', 'GET /ARTICLES/SLUG', :call, false],
      ['cloudflare', 'astro_origin', 'CACHE MISS · ORIGIN', :call, false],
      ['astro_origin', 'astro_origin', 'RENDER MDX', :call, false],
      ['astro_origin', 'cloudflare', '200 · HTML + MAX-AGE', :return, true],
      ['cloudflare', 'reader', '200 · EDGE-CACHED', :success, false],
      ['reader', 'analytics', 'PAGEVIEW BEACON', :async, true]
    ])
    expect(diagram.layout.activations.map { |bar| bar[:actor] }).to eq(%w[cloudflare astro_origin])
  end

  it 'models the pinned month-level Timeline milestones on an honest date scale' do
    diagram = ParityFixtures::TimelineProductLaunch.diagram

    expect(diagram.title).to eq('Product launch · fourteen months')
    expect(diagram.scale).to eq(:date)
    expect(diagram.events.map { |event| [event.date, event.label, event.detail, event.emphasis] }).to eq([
      ['2025-02-01', 'First post', 'FEB 2025', false],
      ['2025-04-01', 'Design v1', 'APR 2025', false],
      ['2025-09-01', 'Design v2', 'SEP 2025 · typography pass', false],
      ['2026-01-01', 'Design v3', 'JAN 2026 · complexity budget', true],
      ['2026-04-01', 'Schematic skill', 'APR 2026 · NOW · eight diagram types', true]
    ])
  end

  it 'maps every foundation baseline case to the matching pinned record and explicit presentation status' do
    index = JSON.parse(File.read(File.join(FOUNDATION_ROOT, 'docs/roadmap/parity-fixtures-v0.json')))
    registry = JSON.parse(File.read(File.join(FOUNDATION_ROOT, 'docs/roadmap/parity-harness-fixtures.json')))
    fixtures = registry.fetch('fixtures').to_h { |fixture| [fixture.fetch('id'), fixture] }

    TYPES.each do |type|
      batch = JSON.parse(File.read(File.join(FOUNDATION_ROOT, "docs/roadmap/parity-batches/#{type}.json")))
      expect(batch.fetch('cases').map { |item| item.fetch('baseline_case_id') }).to eq(%W[#{type}:minimal-light #{type}:minimal-dark #{type}:full-editorial])
      batch.fetch('cases').each do |item|
        record = index.fetch('records').find { |candidate| candidate.fetch('baseline_case_id') == item.fetch('baseline_case_id') }
        expect(record).not_to be_nil
        expect(record.fetch('type')).to eq(type)
        expect(record.dig('local_render', 'variant')).to eq(item.fetch('local_variant'))
        variant = fixtures.fetch(item.fetch('local_fixture')).fetch('variants').fetch(item.fetch('local_variant'))
        expect(variant.fetch('status')).to eq(item.fetch('local_render'))
      end
    end
  end

  it 'dispatches minimal light and dark profiles with the exact pinned fixture semantics' do
    Dir.mktmpdir do |directory|
      TYPES.each do |type|
        output, status = Open3.capture2e(File.join(FOUNDATION_ROOT, 'bin/audit-parity-batch'), type, '--render-only', '--output-root', File.join(directory, type))
        expect(status).to be_success, output
        %w[minimal-light minimal-dark full-editorial].each do |variant|
          expect(File).to exist(File.join(directory, type, 'generated', "#{type}__#{variant}.html"))
        end
      end
    end

    TYPES.zip(%w[flowchart-skill-decision sequence-article-request timeline-product-launch]).each do |_type, fixture|
      Dir.mktmpdir do |directory|
        output_path = File.join(directory, 'minimal-dark.html')
        output, status = Open3.capture2e(File.join(FOUNDATION_ROOT, 'bin/render-parity-fixture'), fixture, '--variant', 'minimal-dark', '--output', output_path)
        expect(status).to be_success, output
        expect(File.read(output_path)).to include('data-sgr-style="minimal"', 'data-sgr-theme="dark"')
      end
    end
  end
end
