# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/stream_weaver'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/reader'
require 'stream_weaver/export/html_exporter'

RSpec.describe 'DP security matrices in StreamWeaver' do
  let(:source) { File.read(File.expand_path('../../examples/stream_weaver/dp_security_matrices.rb', __dir__), encoding: 'UTF-8') }

  it 'renders, reopens, and exports paired static UTF-8 connector-free SVG' do
    live = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'dp-security-matrices')
    reopened = StreamWeaver::Canvas::Reader.render_doc(source).html
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(live.error).to be_nil
    [live.html, reopened, exported].each do |html|
      expect(html.encoding).to eq(Encoding::UTF_8)
      expect(html.scan('data-sgr-dp-security-matrix="true"').size).to eq(2)
      expect(html).to include('Recorded access · light', 'Recorded access · dark',
                              'data-sgr-theme="light"', 'data-sgr-theme="dark"',
                              'data-security-level="unknown"', 'published aggregate',
                              'Cathryn Lavery', 'Omission fails')
      expect(html).not_to include('marker-end=', 'DSL error:', 'mermaid.esm', '<script type="text/html"')
    end
  end
end
