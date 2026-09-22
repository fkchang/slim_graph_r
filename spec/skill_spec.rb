# frozen_string_literal: true

require 'spec_helper'
require 'slim_graph_r/cli'
require 'tmpdir'
require 'stringio'

RSpec.describe 'the packaged SlimGraphR agent skill' do
  let(:root) { File.expand_path('..', __dir__) }
  let(:skill_dir) { File.join(root, 'skills', 'slim-graph-r') }
  let(:skill) { File.read(File.join(skill_dir, 'SKILL.md'), encoding: 'UTF-8') }
  let(:references) { Dir[File.join(skill_dir, 'references', '*.md')].sort }
  let(:family_references) { references.reject { |path| path.end_with?('/semantic-patterns.md') } }

  it 'routes progressively to semantic patterns and exactly six family references' do
    linked = skill.scan(%r{\(references/([^)]+\.md)\)}).flatten

    expect(linked).to contain_exactly('semantic-patterns.md', 'systems.md', 'data.md', 'flow.md',
                                      'hierarchy.md', 'strategy.md', 'quantitative.md')
    expect(references.map { |path| File.basename(path) }).to contain_exactly(*linked)
  end

  it 'accounts for every supported type exactly once in family inventories' do
    documented = family_references.flat_map do |path|
      line = File.readlines(path, encoding: 'UTF-8').find { |entry| entry.start_with?('**Supported:**') }
      line.scan(/`:(\w+)`/).flatten.map(&:to_sym)
    end

    expect(documented).to contain_exactly(*SlimGraphR::Diagram::TYPES)
    expect(documented.length).to eq(SlimGraphR::Diagram::TYPES.length)
  end

  it 'keeps the representative pattern in each family executable' do
    family_references.each do |path|
      source = File.read(path, encoding: 'UTF-8').scan(/```ruby\n(.*?)\n```/m).flatten.fetch(0)
      diagram = eval(source, TOPLEVEL_BINDING, path, 1) # rubocop:disable Security/Eval

      expect(diagram.to_svg).to include('<svg', '<title', '<desc')
    end
  end

  it 'installs the entire skill for cross-tool and Claude discovery' do
    Dir.mktmpdir do |dir|
      output = StringIO.new
      errors = StringIO.new
      status = nil
      Dir.chdir(dir) { status = SlimGraphR::CLI.run(%w[install-skill], output: output, errors: errors) }

      expect(status).to eq(0), errors.string
      %w[.agents .claude].each do |surface|
        installed = File.join(dir, surface, 'skills', 'slim-graph-r')
        expect(File.symlink?(installed)).to be(true)
        expect(File.exist?(File.join(installed, 'SKILL.md'))).to be(true)
        expect(Dir[File.join(installed, 'references', '*.md')].length).to eq(7)
      end
    end
  end

  it 'protects a customized destination unless force is explicit' do
    Dir.mktmpdir do |dir|
      destination = File.join(dir, '.agents', 'skills', 'slim-graph-r')
      FileUtils.mkdir_p(destination)
      File.write(File.join(destination, 'SKILL.md'), 'custom')
      errors = StringIO.new

      Dir.chdir(dir) do
        expect(SlimGraphR::CLI.run(%w[install-skill], output: StringIO.new, errors: errors)).to eq(1)
        expect(File.read(File.join(destination, 'SKILL.md'))).to eq('custom')
        expect(SlimGraphR::CLI.run(%w[install-skill --force], output: StringIO.new, errors: errors)).to eq(0)
      end
      expect(File.symlink?(destination)).to be(true)
    end
  end

  it 'ships the entrypoint, UI metadata, and every reference in the gem manifest' do
    specification = Gem::Specification.load(File.join(root, 'slim_graph_r.gemspec'))
    expected = ['skills/slim-graph-r/SKILL.md', 'skills/slim-graph-r/agents/openai.yaml'] +
      references.map { |path| path.delete_prefix("#{root}/") }

    expect(specification.files).to include(*expected)
    expect(specification.files).to include('docs/motion-contract.md')
  end
end
