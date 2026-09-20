# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/stream_weaver'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/reader'
require 'stream_weaver/export/html_exporter'

RSpec.describe 'ER diagrams in StreamWeaver' do
  let(:source) { File.read(File.expand_path('../../examples/stream_weaver/entity_relationships.rb', __dir__), encoding: 'UTF-8') }

  it 'renders, reopens, and exports paired static UTF-8 arrow-free SVG' do
    live = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'entity-relationships')
    reopened = StreamWeaver::Canvas::Reader.render_doc(source).html
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(live.error).to be_nil
    [live.html, reopened, exported].each do |html|
      expect(html.encoding).to eq(Encoding::UTF_8)
      expect(html.scan('data-er="true"').size).to eq(2)
      expect(html).to include('Order domain · light', 'Order domain · dark',
                              'data-sgr-theme="light"', 'data-sgr-theme="dark"',
                              'data-er-cardinality="0..*"', 'declared foreign key',
                              'Cathryn Lavery', 'Field names never infer physical foreign keys')
      expect(html).not_to include('<marker', 'marker-end=', 'DSL error:', 'mermaid.esm', '<script type="text/html"')
    end
  end
end
