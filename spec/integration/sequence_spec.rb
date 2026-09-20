require 'spec_helper'
require 'slim_graph_r/stream_weaver'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/reader'
require 'stream_weaver/export/html_exporter'

RSpec.describe 'Sequence frames in StreamWeaver' do
  let(:source) { File.read(File.expand_path('../../examples/stream_weaver/sequences.rb', __dir__), encoding: 'UTF-8') }

  it 'preserves activation and branch meaning through canvas, reader, and HTML export' do
    live = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'sequence')
    expect(live.error).to be_nil
    saved = StreamWeaver::Canvas::Reader.render_doc(source).html
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    [live.html, saved, exported].each do |html|
      expect(html).to include('data-sgr-activation="api"', 'data-sgr-frame="alt"', 'data-sgr-frame="opt"', 'data-sgr-frame="loop"', '[not cached]')
      expect(html).not_to include('DSL error:')
    end
  end
end
