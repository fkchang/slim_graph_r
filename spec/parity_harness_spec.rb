# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require 'json'
require_relative 'spec_helper'
require_relative '../examples/parity/architecture_content_site'

RSpec.describe 'Architecture parity harness batch' do
  HARNESS_ROOT = File.expand_path('..', __dir__)

  it 'models the pinned Architecture content-site semantics in the editorial fixture' do
    diagram = ParityFixtures::ArchitectureContentSite.diagram

    expect(diagram.nodes.map { |node| [node.id, node.label, node.detail] }).to eq([
      ['reader', 'Reader', 'Browser'],
      ['cloudflare', 'Cloudflare', 'Pages · cache'],
      ['astro_origin', 'Astro Origin', 'SSR + MDX'],
      ['mdx_bundle', 'MDX Bundle', 'src/content/*.mdx'],
      ['content_cms', 'Content CMS', 'assets · og images']
    ])
    expect(diagram.nodes.select(&:emphasis).map(&:id)).to eq(['astro_origin'])
    expect(diagram.edges.map { |edge| [edge.from, edge.to, edge.label, edge.dashed] }).to eq([
      ['reader', 'cloudflare', 'HTTPS', false],
      ['cloudflare', 'reader', 'RESP', true],
      ['cloudflare', 'astro_origin', 'SSR', false],
      ['astro_origin', 'mdx_bundle', 'READ MDX', false],
      ['astro_origin', 'content_cms', 'QUERY', false]
    ])
  end

  it 'renders each minimal variant through its own profile without substituting editorial' do
    Dir.mktmpdir do |directory|
      %w[minimal-light minimal-dark].each do |variant|
        output_path = File.join(directory, "#{variant}.html")
        output, status = Open3.capture2e(File.join(HARNESS_ROOT, 'bin/render-parity-fixture'), 'architecture-content-site', '--variant', variant, '--output', output_path)

        expect(status).to be_success, output
        expect(File.read(output_path)).to include('data-sgr-style="minimal"', "data-sgr-theme=\"#{variant.delete_prefix('minimal-')}\"")
      end
    end
  end

  it 'renders the editorial fixture to a standalone browser page' do
    Dir.mktmpdir do |directory|
      output_path = File.join(directory, 'architecture.html')
      output, status = Open3.capture2e(File.join(HARNESS_ROOT, 'bin/render-parity-fixture'), 'architecture-content-site', '--variant', 'full-editorial', '--output', output_path)

      expect(status).to be_success, output
      expect(File.read(output_path)).to include('role="img"')
      expect(File.read(output_path)).to include('Content site in production')
    end
  end

  it 'declares minimal renders captured with their exact requested variants' do
    batch = JSON.parse(File.read(File.join(HARNESS_ROOT, 'docs/roadmap/parity-batches/architecture.json')))
    minimal = batch.fetch('cases').select { |item| item.fetch('baseline_case_id').include?('minimal') }

    expect(minimal.map { |item| item.fetch('local_render') }).to eq(%w[captured captured])
    expect(minimal.map { |item| item.fetch('local_fixture') }).to eq(%w[architecture-content-site architecture-content-site])
    expect(minimal.map { |item| item.fetch('local_variant') }).to eq(%w[minimal-light minimal-dark])
  end

  it 'dispatches the selected fixture and variant through the registry' do
    Dir.mktmpdir do |directory|
      output, status = Open3.capture2e(
        File.join(HARNESS_ROOT, 'bin/audit-parity-batch'), 'architecture', '--render-only', '--output-root', directory
      )

      expect(status).to be_success, output
      %w[minimal-light minimal-dark full-editorial].each do |variant|
        html = File.read(File.join(directory, 'generated', "architecture__#{variant}.html"))
        expect(html).to include('Content site in production')
      end
    end
  end

  it 'fails clearly for an unknown fixture or variant' do
    output, status = Open3.capture2e(File.join(HARNESS_ROOT, 'bin/render-parity-fixture'), 'not-a-fixture', '--variant', 'full-editorial', '--output', '/tmp/ignored.html')
    expect(status).not_to be_success
    expect(output).to include('Unknown parity fixture: not-a-fixture')

    output, status = Open3.capture2e(File.join(HARNESS_ROOT, 'bin/render-parity-fixture'), 'architecture-content-site', '--variant', 'not-a-variant', '--output', '/tmp/ignored.html')
    expect(status).not_to be_success
    expect(output).to include('Unknown parity fixture variant "not-a-variant" for architecture-content-site')
  end
end
