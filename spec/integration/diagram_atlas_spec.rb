# frozen_string_literal: true

require 'spec_helper'
require 'slim_graph_r/stream_weaver'
require 'stream_weaver/component_renderer'

RSpec.describe 'the packaged diagram atlas' do
  let(:path) { File.expand_path('../../examples/stream_weaver/gallery.rb', __dir__) }
  let(:source) { File.read(path, encoding: 'UTF-8') }
  let(:app) do
    StreamWeaver::App.new('Diagram atlas').tap do |atlas|
      atlas.instance_eval(source, path)
    end
  end

  it 'renders one real StreamWeaver diagram component for every supported type' do
    diagrams = app.components.grep(SlimGraphR::StreamWeaverComponent)

    expect(app.theme).to eq(:doc)
    expect(diagrams.map { |component| component.diagram.type }).to match_array(SlimGraphR::Diagram::TYPES)
    expect(diagrams.length).to eq(SlimGraphR::Diagram::TYPES.length)
  end

  it 'shows the exact executable Ruby for every diagram with use and limit guidance' do
    diagrams = app.components.grep(SlimGraphR::StreamWeaverComponent)
    code_blocks = app.components.grep(StreamWeaver::Components::CodeBlock)
    shown_types = code_blocks.filter_map { |block| block.code[/\bdiagram\s+:([a-z_]+)/, 1]&.to_sym }

    expect(shown_types).to match_array(SlimGraphR::Diagram::TYPES)
    expect(code_blocks.length).to eq(diagrams.length)

    html = StreamWeaver::ComponentRenderer.render_html(StreamWeaver::Adapter::AlpineJS.new, app.components)
    expect(html.scan('<strong>Use when:</strong>').length).to eq(SlimGraphR::Diagram::TYPES.length)
    expect(html.scan('<strong>Limit:</strong>').length).to eq(SlimGraphR::Diagram::TYPES.length)
  end
end
