# frozen_string_literal: true

require 'spec_helper'
require 'open3'
require 'rbconfig'

RSpec.describe 'the README visual sampler' do
  let(:root) { File.expand_path('..', __dir__) }
  let(:examples) do
    {
      'deployment' => 'deployment',
      'er' => 'entity_relationships',
      'flowchart' => 'flowchart',
      'tree' => 'tree',
      'quadrant' => 'quadrant',
      'bar' => 'bar'
    }
  end

  def normalize(svg)
    svg.force_encoding(Encoding::UTF_8).gsub(/sgr-[0-9a-f]{12}/, 'sgr-ID').strip
  end

  it 'embeds one real output for each chooser family with accessible text' do
    readme = File.read(File.join(root, 'README.md'), encoding: 'UTF-8')
    embedded = readme.scan(%r{examples/rendered/readme-([a-z-]+)\.svg}).flatten

    expect(embedded).to contain_exactly(*examples.keys)
    examples.each_key do |name|
      svg = File.read(File.join(root, 'examples', 'rendered', "readme-#{name}.svg"), encoding: 'UTF-8')
      expect(svg).to include('<svg', '<title', '<desc', 'data-sgr-style="ruby"')
    end
  end

  it 'keeps every embedded SVG equal to its executable Ruby source' do
    examples.each do |asset, source|
      output, errors, status = Open3.capture3(
        RbConfig.ruby, '-I', File.join(root, 'lib'), File.join(root, 'exe', 'slimgraph'),
        'render', File.join(root, 'examples', 'standalone', "#{source}.rb"), '--style', 'ruby'
      )
      expect(status).to be_success, errors
      expected = File.read(File.join(root, 'examples', 'rendered', "readme-#{asset}.svg"), encoding: 'UTF-8')
      expect(normalize(output)).to eq(normalize(expected))
    end
  end

  it 'documents a quickstart that runs without a source checkout' do
    readme = File.read(File.join(root, 'README.md'), encoding: 'UTF-8')

    expect(readme).to include('gem install slim_graph_r')
    expect(readme).to include("ruby -r slim_graph_r -e")
    expect(readme).not_to include('gem install ./tmp/', 'slimgraph render examples/standalone/publishing.rb')
  end
end
