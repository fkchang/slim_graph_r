# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/stream_weaver'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/reader'
require 'stream_weaver/export/html_exporter'

RSpec.describe 'Data flow in StreamWeaver' do
  let(:source) { File.read(File.expand_path('../../examples/stream_weaver/data_flows.rb', __dir__), encoding: 'UTF-8') }

  it 'renders, reopens, and exports paired static UTF-8 inline SVG with generated semantics' do
    live = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'data-flows')
    expect(live.error).to be_nil
    reopened = StreamWeaver::Canvas::Reader.render_doc(source).html
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    [live.html, reopened, exported].each do |html|
      expect(html.encoding).to eq(Encoding::UTF_8)
      expect(html.scan('data-sgr-data-flow="true"').size).to eq(2)
      expect(html).to include('Reporting pipeline · light', 'Reporting pipeline · dark',
                              'data-sgr-theme="light"', 'data-sgr-theme="dark"',
                              'data-sgr-focal-label-mask="true"', 'input not declared',
                              'Cathryn Lavery', '2–4 roles')
      expect(html).not_to include('DSL error:', 'mermaid.esm', '<script type="text/html"')
    end
  end
end
