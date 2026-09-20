# frozen_string_literal: true

require 'json'
require 'open3'
require 'tmpdir'
require_relative 'spec_helper'
require_relative '../examples/parity/er_publishing_domain'
require_relative '../examples/parity/db_schema_checkout'
require_relative '../examples/parity/uml_class_payments'
require_relative '../examples/parity/quadrant_publication_priorities'

RSpec.describe 'Data-model parity batches' do
  ROOT_DATA_MODEL = File.expand_path('..', __dir__)
  TYPES_DATA_MODEL = %w[er db-schema uml-class quadrant].freeze

  it 'preserves every pinned semantic inventory before recording its exact residual' do
    expect(ParityFixtures::ERPublishingDomain::ENTITIES.fetch('Article')).to include('# id uuid', '→ author_id uuid', 'og_image text · url')
    expect(ParityFixtures::ERPublishingDomain::RELATIONSHIPS).to include(['Author', 'Article', '1', 'N', 'WRITES'])
    expect(ParityFixtures::DBSchemaCheckout::TABLES.fetch('public.products')).to include('+3_more_columns')
    expect(ParityFixtures::DBSchemaCheckout::FOREIGN_KEYS).to include(['order_items.order_id', 'orders.id', :cascade])
    expect(ParityFixtures::UMLClassPayments::CLASSES.fetch('PaymentMethod')).to include('+ authorize(amount: Money): AuthResult')
    expect(ParityFixtures::UMLClassPayments::RELATIONSHIPS).to include('dependency')
    expect(ParityFixtures::QuadrantPublicationPriorities::QUADRANTS).to eq(%w[DO_FIRST MAJOR_PROJECTS QUICK_WINS AVOID])
    expect(ParityFixtures::QuadrantPublicationPriorities::ITEMS).to include('Schematic skill v4', 'Port to Nuxt')
  end

  it 'maps all twelve cases and renders every exact editorial counterpart' do
    registry = JSON.parse(File.read(File.join(ROOT_DATA_MODEL, 'docs/roadmap/parity-harness-fixtures.json'), encoding: 'UTF-8'))
    fixtures = registry.fetch('fixtures').to_h { |fixture| [fixture.fetch('id'), fixture] }
    index = JSON.parse(File.read(File.join(ROOT_DATA_MODEL, 'docs/roadmap/parity-fixtures-v0.json'), encoding: 'UTF-8'))

    TYPES_DATA_MODEL.each do |type|
      batch = JSON.parse(File.read(File.join(ROOT_DATA_MODEL, "docs/roadmap/parity-batches/#{type}.json"), encoding: 'UTF-8'))
      expect(batch.fetch('cases').map { |item| item.fetch('baseline_case_id') }).to eq(["#{type}:minimal-light", "#{type}:minimal-dark", "#{type}:full-editorial"])
      batch.fetch('cases').each do |item|
        variant = fixtures.fetch(item.fetch('local_fixture')).fetch('variants').fetch(item.fetch('local_variant'))
        expect(variant.fetch('status')).to eq(item.fetch('local_render'))
        expect(index.fetch('records').count { |record| record.fetch('baseline_case_id') == item.fetch('baseline_case_id') }).to eq(1)
      end
    end

    Dir.mktmpdir do |directory|
      TYPES_DATA_MODEL.each do |type|
        output, status = Open3.capture2e(File.join(ROOT_DATA_MODEL, 'bin/audit-parity-batch'), type, '--render-only', '--output-root', File.join(directory, type))
        expect(status).to be_success, output
        rendered = Dir.glob(File.join(directory, type, 'generated', '*.html'))
        batch_cases = JSON.parse(File.read(File.join(ROOT_DATA_MODEL, "docs/roadmap/parity-batches/#{type}.json"), encoding: 'UTF-8')).fetch('cases')
        expected = batch_cases.select { |item| item.fetch('local_render') == 'captured' }.map { |item| File.join(directory, type, 'generated', "#{type}__#{item.fetch('local_variant')}.html") }.sort
        expect(rendered.sort).to eq(expected)
      end
    end
  end

  it 'dispatches ER and database-schema by stable case ID without cross-type leaks' do
    Dir.mktmpdir do |directory|
      { 'er' => '<title>Publishing domain</title>', 'db-schema' => '<title>Checkout persistence</title>' }.each do |type, title|
        output, status = Open3.capture2e(File.join(ROOT_DATA_MODEL, 'bin/audit-parity-batch'), type, '--render-only', '--output-root', File.join(directory, type))
        expect(status).to be_success, output

        rendered = Dir.glob(File.join(directory, type, 'generated', '*.html'))
        expected = File.join(directory, type, 'generated', "#{type}__full-editorial.html")
        batch_cases = JSON.parse(File.read(File.join(ROOT_DATA_MODEL, "docs/roadmap/parity-batches/#{type}.json"), encoding: 'UTF-8')).fetch('cases')
        expected_paths = batch_cases.select { |item| item.fetch('local_render') == 'captured' }.map { |item| File.join(directory, type, 'generated', "#{type}__#{item.fetch('local_variant')}.html") }
        expect(rendered.sort).to eq(expected_paths.sort)
        expect(File.read(expected, encoding: 'UTF-8')).to include(title)
      end
    end
  end

  it 'renders the newly exact ER and database-schema editorial fixtures directly while browser capture awaits its gate' do
    %w[er-publishing-domain db-schema-checkout].each do |fixture|
      Dir.mktmpdir do |directory|
        output = File.join(directory, "#{fixture}.html")
        source = File.join(ROOT_DATA_MODEL, 'examples/parity', fixture.tr('-', '_') + '.rb')
        require source
        receiver = fixture == 'er-publishing-domain' ? ParityFixtures::ERPublishingDomain : ParityFixtures::DBSchemaCheckout
        File.write(output, receiver.diagram.to_html)
        expect(File.read(output, encoding: 'UTF-8')).to include('<svg')
      end
    end
  end
end
