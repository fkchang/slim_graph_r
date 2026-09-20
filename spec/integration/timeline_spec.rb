require 'spec_helper'
require 'slim_graph_r/stream_weaver'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/reader'
require 'stream_weaver/export/html_exporter'

RSpec.describe 'Calendar timeline integration' do
  it 'keeps the same date markers and simultaneous event counts in every document context' do
    source = File.read(File.expand_path('../../examples/stream_weaver/timelines.rb', __dir__), encoding: 'UTF-8')
    live = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'timelines')
    expect(live.error).to be_nil
    saved = StreamWeaver::Canvas::Reader.render_doc(source).html
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    markers = [live.html, saved, exported].map { |html| html.scan(/<circle[^>]*data-sgr-date[^>]*>/) }
    expect(markers[0].size).to eq(8) # Four dates, two color modes.
    expect(markers.uniq.size).to eq(1)
    expect(markers[0].join).to include('data-sgr-event-count="2"')
  end
end
