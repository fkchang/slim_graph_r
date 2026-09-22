# frozen_string_literal: true

require 'json'
require 'digest'
require 'open3'

RSpec.describe 'V0 parity fixtures' do
  ROOT = File.expand_path('../..', __dir__)
  INDEX = JSON.parse(File.read(File.join(ROOT, 'docs/roadmap/parity-fixtures-v0.json'), encoding: Encoding::UTF_8))

  it 'contains the pinned 39 by 3 baseline without verified promotion' do
    expect(INDEX.fetch('upstream_revision')).to eq('dcd9317ed9ec7477b20005544f36e3313664d815')
    expect(INDEX.fetch('records').length).to eq(117)
    expect(INDEX.fetch('records').map { |r| [r['type'], r['baseline_case_id']] }.uniq.length).to eq(117)
    expect(INDEX.fetch('records').count { |r| r.dig('audit', 'classification') == 'verified' }).to eq(0)
  end

  it 'preserves the pinned upstream identity contract' do
    identity = INDEX.fetch('records').map do |record|
      [
        record.fetch('type'),
        record.fetch('baseline_case_id'),
        record.dig('upstream_asset', 'local_path'),
        record.dig('upstream_asset', 'sha256'),
        record.dig('upstream_contract', 'local_path'),
        record.dig('upstream_contract', 'sha256'),
        record.dig('upstream_contract', 'anchor')
      ]
    end

    expect(Digest::SHA256.hexdigest(JSON.generate(identity))).to eq(
      '6508a2fb4a570f769105906b2445d88d8e40369b6c57b61e859a6516e8f29842'
    )
  end

  it 'passes the deterministic byte and policy checker under the C locale' do
    output, status = Open3.capture2e({ 'LC_ALL' => 'C', 'LANG' => 'C' }, File.join(ROOT, 'bin/check-parity-fixtures'))
    expect(status).to be_success, output
    expect(output).to include('117 records/evidence outcomes; 96 supported-unverified')
  end

  it 'keeps minimal captures paired to the same type fixture with no availability leaks' do
    registry = JSON.parse(File.read(File.join(ROOT, 'docs/roadmap/parity-harness-fixtures.json'), encoding: Encoding::UTF_8))
    fixture_by_id = registry.fetch('fixtures').to_h { |fixture| [fixture.fetch('id'), fixture] }
    records = INDEX.fetch('records').to_h { |record| [record.fetch('baseline_case_id'), record] }
    mismatches = []

    Dir[File.join(ROOT, 'docs/roadmap/parity-batches/*.json')].each do |path|
      batch = JSON.parse(File.read(path, encoding: Encoding::UTF_8))
      batch.fetch('cases').each do |entry|
        id = entry.fetch('baseline_case_id')
        next unless id.end_with?(':minimal-light', ':minimal-dark')

        type = id.split(':', 2).first
        fixture = fixture_by_id.fetch(entry.fetch('local_fixture'))
        expected_status = records.fetch(id).dig('audit', 'classification') == 'supported-unverified'
        actual_status = fixture.fetch('variants').fetch(entry.fetch('local_variant')).fetch('status') == 'captured'
        mismatches << id unless expected_status == actual_status
        mismatches << id unless entry.fetch('local_fixture').start_with?(type)
        next unless actual_status

        mismatches << id unless fixture.fetch('variants').fetch(entry.fetch('local_variant')).fetch('arguments').fetch('style') == 'minimal'
        mismatches << id unless fixture.fetch('variants').fetch(entry.fetch('local_variant')).fetch('arguments').fetch('theme') == entry.fetch('local_variant').delete_prefix('minimal-')
      end
    end

    expect(mismatches).to be_empty
  end

  it 'joins batches, evidence, manifest status, and fixture hashes by baseline case ID' do
    records = INDEX.fetch('records').to_h { |record| [record.fetch('baseline_case_id'), record] }
    manifest = JSON.parse(File.read(File.join(ROOT, 'docs/roadmap/parity-manifest.json'), encoding: Encoding::UTF_8))
    manifest_by_type = manifest.fetch('types').to_h { |entry| [entry.fetch('type'), entry] }
    visited = []

    Dir[File.join(ROOT, 'docs/roadmap/parity-batches/*.json')].sort.each do |path|
      type = File.basename(path, '.json')
      batch = JSON.parse(File.read(path, encoding: Encoding::UTF_8))
      summary = JSON.parse(File.read(File.join(ROOT, 'artifacts/parity/v0', type, 'summary.json'), encoding: Encoding::UTF_8))
      outcomes = summary.fetch('outcomes').to_h { |outcome| [outcome.fetch('baseline_case_id'), outcome] }

      batch.fetch('cases').each do |entry|
        id = entry.fetch('baseline_case_id')
        record = records.fetch(id)
        outcome = outcomes.fetch(id)
        variant = entry.fetch('local_variant')
        visited << id

        expect(id).to start_with("#{type}:")
        expect(entry.fetch('local_fixture')).to start_with(type)
        expect(record.fetch('type')).to eq(type)
        expect(outcome.fetch('classification')).to eq(record.dig('audit', 'classification'))
        local_status = outcome.dig('local', 'status')
        expect([local_status, entry.fetch('local_render')]).to satisfy(
          "#{id} evidence should be captured or explicitly awaiting the browser gate"
        ) { |actual, configured| actual == configured || (configured == 'captured' && actual == 'rendered-awaiting-browser-gate') }
        expect(manifest_by_type.fetch(type).dig('baseline_case_status', variant, 'classification')).to eq(
          record.dig('audit', 'classification')
        )

        fixture = record.fetch('local_semantic_fixture')
        expect(Digest::SHA256.file(File.join(ROOT, fixture.fetch('path'))).hexdigest).to eq(fixture.fetch('sha256'))
      end
    end

    expect(visited.sort).to eq(records.keys.sort)
  end
end
