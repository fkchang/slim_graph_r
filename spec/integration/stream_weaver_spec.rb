require 'spec_helper'
require 'slim_graph_r/stream_weaver'
require 'stream_weaver/component_renderer'
require 'stream_weaver/canvas/bridge'
require 'stream_weaver/canvas/reader'
require 'stream_weaver/export/html_exporter'

RSpec.describe 'StreamWeaver extension' do
  let(:dsl) do
    <<~RUBY
      require 'slim_graph_r/stream_weaver'
      diagram :architecture, title: 'Document flow' do
        node :draft
        node :published, emphasis: true
        flow :draft, :published
      end
    RUBY
  end

  it 'adds a real component to the DSL and renders through the adapter-independent interface' do
    app = StreamWeaver::App.new('Spec')
    app.instance_eval(dsl)
    expect(app.components.last).to be_a(SlimGraphR::StreamWeaverComponent)
    [StreamWeaver::Adapter::AlpineJS.new, Object.new].each do |adapter|
      html = StreamWeaver::ComponentRenderer.render_html(adapter, app.components)
      expect(html).to include('<svg', 'Document flow', 'role="region"')
      expect(html).not_to include('&lt;svg')
    end
  end

  it 'preserves diagram DSL through canvas push/get_dsl and renders it' do
    bridge = StreamWeaver::Canvas::Bridge.new
    bridge.handle_claude_message(type: 'create', name: 'spec')
    result = bridge.handle_claude_message(type: 'push', name: 'spec', dsl: dsl)
    expect(result[:type]).not_to eq('error'), result.inspect
    expect(bridge.get_session('spec').html).to include('<svg')
    expect(bridge.get_session('spec').dsl).to eq(dsl)
  end

  it 'reopens saved DSL in the canvas reader' do
    html = StreamWeaver::Canvas::Reader.render_doc(dsl).html
    expect(html).to include('<svg', 'Document flow')
    expect(html).not_to include('DSL error')
  end

  it 'exports the saved DSL as inline SVG without a diagram script' do
    html = StreamWeaver::Export::HtmlExporter.from_dsl(dsl).to_html
    expect(html).to include('<svg', 'Document flow')
    expect(html).not_to include('mermaid.esm', 'chart.umd')
  end

  it 'keeps live, extension, reader and export SVGs fluid inside local scroll regions' do
    app = StreamWeaver::App.new('Spec')
    app.instance_eval(dsl)
    extension_html = StreamWeaver::ComponentRenderer.render_html(StreamWeaver::Adapter::AlpineJS.new, app.components)
    live_html = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, dsl, session_name: 'responsive').html
    reader_html = StreamWeaver::Canvas::Reader.render_doc(dsl).html
    export_html = StreamWeaver::Export::HtmlExporter.from_dsl(dsl).to_html

    [extension_html, live_html, reader_html, export_html].each do |html|
      root = html[/<svg[^>]+>/]
      expect(html).to include('overflow-x:auto', 'role="region"')
      expect(root).to include('width:100%', 'min-width:', 'data-sgr-display-scale=')
      expect(root).not_to include('max-width:')
      expect(html).not_to include('mermaid.esm', 'chart.umd', 'transform:scale', 'zoom:')
    end
  end

  it 'renders every gallery example through live canvas, Canvas Reader and export' do
    source = File.read(File.expand_path('../../examples/stream_weaver/gallery.rb', __dir__), encoding: 'UTF-8')
    result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'gallery')
    expect(result.error).to be_nil
    expect(result.html.scan('<svg').size).to eq(SlimGraphR::Diagram::TYPES.length)
    expect(result.html).to include('data-sgr-venn="true"', 'data-sgr-loop="true"', 'data-sgr-fishbone="true"',
                                   'data-sgr-wardley="true"', 'data-sgr-treemap="true"', 'data-sgr-sankey="true"',
                                   'data-polar-chart="true"', 'data-radar-chart="true"')

    reader_html = StreamWeaver::Canvas::Reader.render_doc(source).html
    export_html = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    [reader_html, export_html].each do |html|
      expect(html.scan('<svg').size).to eq(SlimGraphR::Diagram::TYPES.length)
      expect(html).not_to include('DSL error:')
    end
  end

  it 'renders, reopens and exports radial examples with captions and no quantitative area fill' do
    source = File.read(File.expand_path('../../examples/stream_weaver/radial.rb', __dir__), encoding: 'UTF-8')
    result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'radial')
    expect(result.error).to be_nil
    expect(result.html).to include('data-polar-chart="true"', 'data-radar-chart="true"', 'AREA HAS NO MEANING')
    expect(result.html).not_to match(/<polygon[^>]+data-radar-entity[^>]+fill="(?!none)/)
    reopened = StreamWeaver::Canvas::Reader.render_doc(source).html
    expect(reopened).to include('data-polar-ray="midday"', 'data-radar-vertex="sqlite:recovery"')
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(exported).to include('data-sgr-display-scale="1.143"', 'POLYGON AREA HAS NO MEANING')
    expect(exported).not_to include('mermaid.esm', '<script type="text/html"')
  end

  it 'renders, reopens and exports Wardley examples as static inline SVG' do
    source = File.read(File.expand_path('../../examples/stream_weaver/wardleys.rb', __dir__), encoding: 'UTF-8')
    result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'wardleys')
    expect(result.error).to be_nil
    expect(result.html.scan('data-sgr-wardley="true"').size).to eq(2)
    expect(result.html).to include('data-sgr-wardley-dependency=', 'data-sgr-wardley-movement=',
                                   'overflow-x:auto', 'tabindex="0"', 'role="region"')

    reopened = StreamWeaver::Canvas::Reader.render_doc(source).html
    expect(reopened).to include('data-sgr-wardley-band="genesis"', 'not calculated scores')
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(exported).to include('<svg', 'data-sgr-wardley="true"', 'data-sgr-display-scale="1"')
    expect(exported).not_to include('DSL error:', 'mermaid.esm', '<script type="text/html"')
  end


  it 'renders, reopens and exports database-schema examples as static inline SVG' do
    source = File.read(File.expand_path('../../examples/stream_weaver/database_schemas.rb', __dir__), encoding: 'UTF-8')
    result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'database-schemas')
    expect(result.error).to be_nil
    expect(result.html.scan('class="sgr-diagram"').size).to eq(2)
    expect(result.html).to include('data-sgr-db-schema-diagram="true"', 'data-sgr-db-column="orders:customer_id"', 'ON DELETE RESTRICT')
    expect(result.html).to include('data-sgr-display-scale="1.333"', 'overflow-x:auto', 'min-width:')

    expect(StreamWeaver::Canvas::Reader.render_doc(source).html).to include('data-sgr-db-schema="public"', 'idx_orders_customer_id')
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(exported).to include('<svg', 'data-sgr-db-port="source"', 'data-sgr-db-port="target"')
    expect(exported).not_to include('mermaid.esm', '<script type="text/html"')
  end

  it 'renders, reopens and exports the ownership example with inline org semantics' do
    source = File.read(File.expand_path('../../examples/stream_weaver/org_charts.rb', __dir__), encoding: 'UTF-8')
    result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'org-charts')
    expect(result.error).to be_nil
    expect(result.html.scan('class="sgr-diagram"').size).to eq(2)
    expect(result.html).to include('sgr-org-rule', 'SETUP NEEDED', 'Production release')

    expect(StreamWeaver::Canvas::Reader.render_doc(source).html).to include('sgr-invoke', 'After-hours coverage')
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(exported).to include('<svg', 'sgr-scope', 'Unowned work')
    expect(exported).not_to include('mermaid.esm', '<script type="text/html"')
  end

  it 'renders, reopens and exports the bounded state-machine example with inline semantics' do
    source = File.read(File.expand_path('../../examples/stream_weaver/state_machines.rb', __dir__), encoding: 'UTF-8')
    result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'state-machines')
    expect(result.error).to be_nil
    expect(result.html.scan('class="sgr-diagram"').size).to eq(2)
    expect(result.html).to include('data-sgr-state-entry', 'data-sgr-state-final', 'data-sgr-state-route="feedback"')

    expect(StreamWeaver::Canvas::Reader.render_doc(source).html).to include('submit [complete?] / queue')
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(exported).to include('<svg', 'data-sgr-state-route="self_loop"', 'attempts &lt; 3')
    expect(exported).not_to include('mermaid.esm', '<script type="text/html"')
  end

  it 'renders, reopens and exports dependency examples as static inline SVG' do
    source = File.read(File.expand_path('../../examples/stream_weaver/dependencies.rb', __dir__), encoding: 'UTF-8')
    result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'dependencies')
    expect(result.error).to be_nil
    expect(result.html.scan('class="sgr-diagram"').size).to eq(2)
    expect(result.html).to include('data-sgr-dependency="external"', 'data-sgr-cycle="true"', '3.2.1 · RubyGems')

    expect(StreamWeaver::Canvas::Reader.render_doc(source).html).to include('data-sgr-dependency="leaf"')
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(exported).to include('<svg', 'data-sgr-cycle="true"')
    expect(exported).not_to include('mermaid.esm', '<script type="text/html"')
  end

  it 'renders, reopens and exports deployment examples as static inline SVG' do
    source = File.read(File.expand_path('../../examples/stream_weaver/deployments.rb', __dir__), encoding: 'UTF-8')
    result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'deployments')
    expect(result.error).to be_nil
    expect(result.html.scan('class="sgr-diagram"').size).to eq(2)
    expect(result.html).to include('data-sgr-deployment-zone="edge"', 'data-sgr-infrastructure="api"',
                                   'data-sgr-artifact="otel sidecar"', 'data-sgr-network="primary-standby"')

    reopened = StreamWeaver::Canvas::Reader.render_doc(source).html
    expect(reopened).to include('data-sgr-replicas="3"', 'Postgres:5432')
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(exported).to include('<svg', 'data-sgr-network-scope="cross-zone"', 'data-sgr-network-async="true"')
    expect(exported).not_to include('mermaid.esm', '<script type="text/html"')
  end


  it 'renders, reopens and exports IT current-state examples as static inline SVG' do
    source = File.read(File.expand_path('../../examples/stream_weaver/it_states.rb', __dir__), encoding: 'UTF-8')
    result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'it-states')
    expect(result.error).to be_nil
    expect(result.html.scan('class="sgr-diagram"').size).to eq(1)
    expect(result.html).to include('data-sgr-it-state="true"', 'data-sgr-phase="collection"',
                                   'data-sgr-system-state="pain_point"', 'data-sgr-crosscut="identity"')

    reopened = StreamWeaver::Canvas::Reader.render_doc(source).html
    expect(reopened).to include('data-sgr-handoff="registry-drive"', 'data-sgr-legend-kind="dashed"')
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(exported).to include('<svg', 'data-sgr-handoff-style="accent"', 'NATSTAT / BEFORE THE PLATFORM')
    expect(exported).not_to include('mermaid.esm', '<script type="text/html"')
  end


  it 'renders, reopens and exports high-level examples as static inline SVG' do
    source = File.read(File.expand_path('../../examples/stream_weaver/high_levels.rb', __dir__), encoding: 'UTF-8')
    result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'high-levels')
    expect(result.error).to be_nil
    expect(result.html.scan('data-sgr-high-level="true"').size).to eq(2)
    expect(result.html).to include('data-sgr-source-zone="true"', 'data-sgr-cluster="Kubernetes"',
                                   'data-sgr-vertical-concern="Security"')

    reopened = StreamWeaver::Canvas::Reader.render_doc(source).html
    expect(reopened).to include('data-sgr-high-level-style="primary"', 'data-sgr-source-type="db"')
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(exported).to include('<svg', 'data-sgr-high-level-style="trigger"', 'data-sgr-crosscut="identity"')
    expect(exported).not_to include('mermaid.esm', '<script type="text/html"')
  end


  it 'renders, reopens and exports all three hierarchy-family examples as static inline SVG' do
    source = File.read(File.expand_path('../../examples/stream_weaver/hierarchy_family.rb', __dir__), encoding: 'UTF-8')
    result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'hierarchy-family')
    expect(result.error).to be_nil
    expect(result.html.scan('class="sgr-diagram"').size).to eq(3)
    expect(result.html).to include('data-sgr-tree="true"', 'data-sgr-nested="true"', 'data-sgr-layers="true"')

    reopened = StreamWeaver::Canvas::Reader.render_doc(source).html
    expect(reopened).to include('data-sgr-tree-bus="platform"', 'data-sgr-scope="task"')
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(exported).to include('<svg', 'data-sgr-indicator="up"', 'data-sgr-layer="transport"')
    expect(exported).not_to include('mermaid.esm', '<script type="text/html"')
  end

  it 'renders, reopens and exports pyramid and medallion examples as static inline SVG' do
    source = File.read(File.expand_path('../../examples/stream_weaver/pyramids_medallions.rb', __dir__), encoding: 'UTF-8')
    result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'pyramids-medallions')
    expect(result.error).to be_nil
    expect(result.html.scan('class="sgr-diagram"').size).to eq(3)
    expect(result.html).to include('data-sgr-pyramid="true"', 'data-sgr-medallion="true"')
    reopened = StreamWeaver::Canvas::Reader.render_doc(source).html
    expect(reopened).to include('data-sgr-pyramid-mode="measured"', 'data-sgr-medallion-tier="bronze"')
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(exported).to include('<svg', '<tspan', 'data-sgr-medallion-promotion="bronze-silver"')
    expect(exported).not_to include('mermaid.esm', '<script type="text/html"')
  end

  it 'renders, reopens and exports swimlane and process examples with UTF-8 intact' do
    source = File.read(File.expand_path('../../examples/stream_weaver/workflows.rb', __dir__), encoding: 'UTF-8')
    result = StreamWeaver::Canvas::Bridge.new.send(:render_dsl, source, session_name: 'workflows')
    expect(result.error).to be_nil
    expect(result.html.scan('class="sgr-diagram"').size).to eq(2)
    expect(result.html).to include('data-sgr-swimlane="true"', 'data-sgr-process="true"', 'Survey delivery — ownership')
    reopened = StreamWeaver::Canvas::Reader.render_doc(source).html
    expect(reopened).to include('data-sgr-activity="draft"', 'data-sgr-operation="pilot"', 'data-sgr-workflow-style="trigger"')
    exported = StreamWeaver::Export::HtmlExporter.from_dsl(source).to_html
    expect(exported).to include('<svg', 'Quarterly survey — tools and payloads', 'data-sgr-payload="TB"')
    expect(exported).not_to include('DSL error:', 'mermaid.esm', '<script type="text/html"')
  end
end
