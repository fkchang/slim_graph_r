# frozen_string_literal: true
require 'json'
require 'open3'
require 'tmpdir'
require_relative 'spec_helper'
require_relative '../examples/parity/it_state_northwind'
require_relative '../examples/parity/high_level_data_stack'
require_relative '../examples/parity/tree_skill_taxonomy'
require_relative '../examples/parity/nested_claude_hierarchy'

RSpec.describe 'IT state, High-Level, Tree, and Nested parity batches' do
  ROOT_STRUCTURE = File.expand_path('..', __dir__)
  TYPES_STRUCTURE = %w[it-state high-level tree nested].freeze

  it 'preserves the exact tree payload while retaining Nested only as an unavailable source model' do
    tree = ParityFixtures::TreeSkillTaxonomy.diagram
    expect(tree.tree_nodes.map(&:label)).to include('Skills', 'Design', 'Engineering', 'Research', 'polish', 'investigate')
    nested = ParityFixtures::NestedClaudeHierarchy.diagram
    expect(nested.containment_scopes.map(&:label)).to eq(['~/.claude/ (global)', '~/vault/ (notes)', '/business', '/marketing', '/project'])
    expect(nested.to_svg).to include('The CLAUDE.md Hierarchy')
    expect(nested.to_svg).not_to include('inherits every level above', 'no imports, no configuration', 'structure IS the index')
  end

  it 'marks unsupported exact compositions unavailable with actionable reasons' do
    expect { ParityFixtures::ItStateNorthwind.diagram }.to raise_error(ArgumentError, /icons.*colors.*footer/)
    expect { ParityFixtures::HighLevelDataStack.diagram }.to raise_error(ArgumentError, /icon catalog.*vertical.*source-to-component/)
  end

  it 'maps all twelve cases and preserves unavailable minimal profiles' do
    registry = JSON.parse(File.read(File.join(ROOT_STRUCTURE, 'docs/roadmap/parity-harness-fixtures.json')))
    fixtures = registry.fetch('fixtures').to_h { |f| [f.fetch('id'), f] }
    TYPES_STRUCTURE.each do |type|
      batch = JSON.parse(File.read(File.join(ROOT_STRUCTURE, "docs/roadmap/parity-batches/#{type}.json")))
      batch.fetch('cases').each do |item|
        variant = fixtures.fetch(item.fetch('local_fixture')).fetch('variants').fetch(item.fetch('local_variant'))
        expect(variant.fetch('status')).to eq(item.fetch('local_render'))
      end
      expect(batch.fetch('cases').first(2).map { |c| c.fetch('local_render') }).to eq(%w[unavailable unavailable])
    end
  end

  it 'dispatches Tree only and rejects Nested as an incomplete editorial counterpart' do
    %w[it-state high-level tree nested].each do |type|
      Dir.mktmpdir do |directory|
        output, status = Open3.capture2e(File.join(ROOT_STRUCTURE, 'bin/audit-parity-batch'), type, '--render-only', '--output-root', directory)
        expect(status).to be_success, output
        editorial = File.join(directory, 'generated', "#{type}__full-editorial.html")
        type == 'tree' ? expect(File).to(exist(editorial)) : expect(File).not_to(exist(editorial))
      end
    end

    output, status = Open3.capture2e(File.join(ROOT_STRUCTURE, 'bin/render-parity-fixture'), 'nested-claude-hierarchy', '--variant', 'full-editorial', '--output', '/tmp/ignored.html')
    expect(status).not_to be_success
    expect(output).to include('is unavailable', 'inner CLAUDE.md document', 'inherits-every-level-above statement', 'annotation model')
  end
end
