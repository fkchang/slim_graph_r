# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/stream_weaver'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/reader'
require 'stream_weaver/export/html_exporter'

RSpec.describe 'Journey family in StreamWeaver' do
  let(:source) { File.read(File.expand_path('../../examples/stream_weaver/journey_family.rb', __dir__), encoding: 'UTF-8') }

  it 'renders, reopens, and exports static UTF-8 inline SVG with complete semantics' do
    live = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'journey-family')
    expect(live.error).to be_nil
    reopened = StreamWeaver::Canvas::Reader.render_doc(source).html
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    [live.html, reopened, exported].each do |html|
      expect(html.encoding).to eq(Encoding::UTF_8)
      expect(html).to include('data-sgr-journey="true"', 'data-sgr-story-map="true"',
                              'Sentiment levels are ordinal, not measured scores',
                              'data-sgr-release-cut="mvp"', 'data-sgr-story-risk="permissions"',
                              'Usage limit is unclear', 'RPT-114 · 3pt')
      expect(html).not_to include('DSL error:', 'mermaid.esm', '<script type="text/html"')
    end
  end
end
