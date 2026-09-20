require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'bounded high-level data stacks' do
  def reference_stack(**options)
    SlimGraphR.diagram(:high_level, title: 'National data platform', cluster: 'Kubernetes', **options) do
      phase :sources, 'Data sources' do
        source :postgres, 'PostgreSQL', type: :db, detail: 'Registry'
        source :drop, 'SFTP drop', type: :ftp
      end
      phase :ingest, 'Ingestion' do
        component :nifi, 'NiFi', role: 'COLL'
      end
      phase :storage, 'Storage' do
        component :minio, 'MinIO', role: 'STORE', focal: true
        component :trino, 'Trino', role: 'VIRT'
      end
      phase :consume, 'Visualization' do
        component :superset, 'Superset', role: 'DASH'
      end
      connect :postgres, :nifi
      connect :drop, :nifi
      connect :nifi, :minio
      connect :minio, :superset
      orchestrate :airflow, 'Airflow', detail: 'Apache Airflow', targets: %i[nifi minio superset]
      crosscut :identity, 'Identity', detail: 'LDAP · OIDC', concern: 'Security'
    end
  end

  def json_data
    {
      type: 'high_level', title: 'National data platform', cluster: 'Kubernetes',
      phases: [
        { id: 'sources', label: 'Data sources', sources: [
          { id: 'postgres', label: 'PostgreSQL', type: 'db', detail: 'Registry' },
          { id: 'drop', label: 'SFTP drop', type: 'ftp' }
        ] },
        { id: 'ingest', label: 'Ingestion', components: [{ id: 'nifi', label: 'NiFi', role: 'COLL' }] },
        { id: 'storage', label: 'Storage', components: [
          { id: 'minio', label: 'MinIO', role: 'STORE', focal: true },
          { id: 'trino', label: 'Trino', role: 'VIRT' }
        ] },
        { id: 'consume', label: 'Visualization', components: [{ id: 'superset', label: 'Superset', role: 'DASH' }] }
      ],
      connections: [
        { from: 'postgres', to: 'nifi' }, { from: 'drop', to: 'nifi' },
        { from: 'nifi', to: 'minio' }, { from: 'minio', to: 'superset' }
      ],
      orchestration: {
        id: 'airflow', label: 'Airflow', detail: 'Apache Airflow',
        targets: %w[nifi minio superset]
      },
      crosscuts: [{ id: 'identity', label: 'Identity', detail: 'LDAP · OIDC', concern: 'Security' }]
    }
  end

  it 'preserves the dedicated Ruby vocabulary and closed model' do
    graph = reference_stack
    expect(graph.type).to eq(:high_level)
    expect(graph.cluster).to eq('Kubernetes')
    expect(graph.phases.map(&:id)).to eq(%w[sources ingest storage consume])
    expect(graph.sources.map { |item| [item.id, item.source_type, item.phase] }).to eq([
      ['postgres', :db, 'sources'], ['drop', :ftp, 'sources']
    ])
    expect(graph.components.map { |item| [item.id, item.role, item.focal, item.phase] }).to include(
      ['minio', 'STORE', true, 'storage']
    )
    expect(graph.orchestration.concern).to eq('Orchestration')
    expect(graph.crosscuts.first.concern).to eq('Security')
    [graph.phases, graph.sources, graph.components, graph.connections, graph.crosscuts].each do |items|
      expect(items).to be_frozen
      items.each { |item| expect(item).to be_frozen }
    end
    expect(graph.orchestration).to be_frozen
    expect(graph.sources.first.label).to be_frozen
  end

  it 'keeps high-level vocabulary out of generic and neighboring types' do
    expect { SlimGraphR.diagram(:architecture) { phase(:a) {} } }.to raise_error(SlimGraphR::Error, /phase.*high-level|IT current-state/i)
    expect { SlimGraphR.diagram(:architecture) { source :a, type: :db } }.to raise_error(SlimGraphR::Error, /source.*high-level/i)
    expect { SlimGraphR.diagram(:architecture) { component :a, role: 'APP' } }.to raise_error(SlimGraphR::Error, /component.*high-level/i)
    expect { SlimGraphR.diagram(:high_level) { node :a } }.to raise_error(SlimGraphR::Error, /component.*phase/i)
    expect { SlimGraphR.diagram(:high_level) { edge :a, :b } }.to raise_error(SlimGraphR::Error, /connect/i)
    expect { SlimGraphR.diagram(:high_level) { handoff :a, :b, 'X' } }.to raise_error(SlimGraphR::Error, /IT current-state/i)
  end

  it 'uses unlabeled connections and rejects the deferred label API clearly' do
    expect { reference_stack }.not_to raise_error
    expect do
      SlimGraphR.diagram(:high_level) { connect :a, :b, 'LAND' }
    end.to raise_error(SlimGraphR::Error, /connect does not accept.*label.*deferred/i)
    expect do
      SlimGraphR::Document.from_json(JSON.generate(json_data.merge(
        connections: [{ from: 'postgres', to: 'nifi', label: 'INGEST' }]
      )))
    end.to raise_error(SlimGraphR::Error, /Unknown connections fields: label/)
  end

  it 'scopes the cluster heading and fixed direction to high-level diagrams' do
    expect(SlimGraphR.diagram(:high_level) do
      phase(:source) { source :a, type: :api }
      phase(:middle) { component :b, role: 'APP', focal: true }
      phase(:end) { component :c, role: 'OUT' }
    end.cluster).to eq('Cluster')
    expect { SlimGraphR.diagram(:architecture, cluster: 'Kubernetes') { node :a } }.to raise_error(SlimGraphR::Error, /cluster.*only.*high-level/i)
    expect { reference_stack(direction: :down) }.to raise_error(SlimGraphR::Error, /fixed :right direction/i)
  end

  it 'requires exactly one explicit focal component without storage-name magic' do
    build = lambda do |focals|
      SlimGraphR.diagram(:high_level) do
        phase(:source) { source :a, type: :api }
        phase(:middle) { component :storage, role: 'STORE', focal: focals.include?(:storage) }
        phase(:end) { component :out, role: 'OUT', focal: focals.include?(:out) }
      end
    end
    expect { build.call([]) }.to raise_error(SlimGraphR::Error, /exactly one explicit focal/i)
    expect { build.call(%i[storage out]) }.to raise_error(SlimGraphR::Error, /exactly one explicit focal/i)
    expect(build.call([:out]).components.find(&:focal).id).to eq('out')
  end

  it 'validates phase roles, reserved concerns, source types, component fields and booleans' do
    expect { SlimGraphR.diagram(:high_level) { phase(:orchestration) { source :a, type: :db } } }.to raise_error(SlimGraphR::Error, /reserved concern.*horizontal phase/i)
    expect do
      SlimGraphR.diagram(:high_level) do
        phase(:one) { component :bad, role: 'APP', focal: true }
        phase(:two) { source :late, type: :api }
        phase(:three) { component :ok, role: 'OUT' }
      end
    end.to raise_error(SlimGraphR::Error, /first high-level phase.*sources|later high-level phase.*components/i)
    expect do
      SlimGraphR.diagram(:high_level) do
        phase(:one) { source :bad, type: :queue }
        phase(:two) { component :ok, role: 'APP', focal: true }
        phase(:three) { component :out, role: 'OUT' }
      end
    end.to raise_error(SlimGraphR::Error, /db, ftp, web, legacy, api/)
    expect do
      SlimGraphR.diagram(:high_level) do
        phase(:one) { source :a, type: :api }
        phase(:two) { component :b, role: '', focal: true }
        phase(:three) { component :c, role: 'OUT' }
      end
    end.to raise_error(SlimGraphR::Error, /role.*blank/i)
    expect do
      SlimGraphR.diagram(:high_level) do
        phase(:one) { source :a, type: :api }
        phase(:two) { component :b, role: 'APP', focal: 'yes' }
        phase(:three) { component :c, role: 'OUT' }
      end
    end.to raise_error(SlimGraphR::Error, /focal must be true or false/i)
  end

  it 'enforces bounded phases, weighted columns, members and a shared ID namespace' do
    expect do
      SlimGraphR.diagram(:high_level) do
        phase(:one, columns: 2) { source :a, type: :api }
        phase(:two, columns: 2) { component :b, role: 'APP', focal: true }
        phase(:three, columns: 2) { component :c, role: 'OUT' }
      end
    end.to raise_error(SlimGraphR::Error, /five weighted columns/i)
    expect do
      SlimGraphR.diagram(:high_level) do
        phase(:same) { source :same, type: :api }
        phase(:two) { component :b, role: 'APP', focal: true }
        phase(:three) { component :c, role: 'OUT' }
      end
    end.to raise_error(SlimGraphR::Error, /IDs.*unique/i)
    expect do
      SlimGraphR.diagram(:high_level) do
        phase(:one) { source :a, type: :api }
        phase(:two) { 3.times { |i| component "c#{i}", role: 'APP', focal: i.zero? } }
        phase(:three) { component :out, role: 'OUT' }
      end
    end.to raise_error(SlimGraphR::Error, /one or two components/i)
  end

  it 'accepts only unique forward connections with valid endpoints and bounded fan-out' do
    expect do
      SlimGraphR.diagram(:high_level) do
        phase(:one) { source :a, type: :api }
        phase(:two) { component :b, role: 'APP', focal: true }
        phase(:three) { component :c, role: 'OUT' }
        connect :c, :b
      end
    end.to raise_error(SlimGraphR::Error, /advance to a later phase/i)
    expect do
      SlimGraphR.diagram(:high_level) do
        phase(:one) { source :a, type: :api }
        phase(:two) { component :b, role: 'APP', focal: true }
        phase(:three) { component :c, role: 'OUT' }
        connect :missing, :b
      end
    end.to raise_error(SlimGraphR::Error, /Unknown high-level endpoint: missing/)
    data = json_data.merge(connections: Array.new(2) { { from: 'postgres', to: 'nifi' } })
    expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error, /Duplicate high-level connections/i)
  end

  it 'builds honest automatic vertical concern pairs and validates trigger targets' do
    expect(reference_stack.orchestration.concern).to eq('Orchestration')
    expect do
      SlimGraphR.diagram(:high_level) do
        phase(:one) { source :a, type: :api }
        phase(:two) { component :top, role: 'APP', focal: true; component :lower, role: 'APP' }
        phase(:three) { component :out, role: 'OUT' }
        orchestrate :flow, targets: [:lower]
      end
    end.to raise_error(SlimGraphR::Error, /top component.*phase/i)
    expect do
      SlimGraphR.diagram(:high_level) do
        phase(:one) { source :a, type: :api }
        phase(:two) { component :b, role: 'APP', focal: true }
        phase(:three) { component :c, role: 'OUT' }
        orchestrate :flow, concern: 'Security', targets: [:b]
        crosscut :identity, concern: 'Security'
      end
    end.to raise_error(SlimGraphR::Error, /concern.*unique/i)
  end

  it 'parses strict JSON with Ruby parity and source semantics intact' do
    graph = SlimGraphR::Document.from_json(JSON.generate(json_data))
    ruby = reference_stack
    expect(graph.phases).to eq(ruby.phases)
    expect(graph.sources).to eq(ruby.sources)
    expect(graph.components).to eq(ruby.components)
    expect(graph.connections).to eq(ruby.connections)
    expect(graph.orchestration).to eq(ruby.orchestration)
    expect(graph.crosscuts).to eq(ruby.crosscuts)
    expect(graph.sources.map(&:source_type)).to eq(%i[db ftp])
    invalid = [
      json_data.merge(cluster: nil),
      json_data.merge(nodes: []),
      json_data.merge(phases: [{ id: 'source', sources: nil }]),
      json_data.merge(orchestration: []),
      json_data.merge(crosscuts: [{ id: 'identity', concern: nil }]),
      json_data.merge(phases: json_data[:phases].tap { |items| items[1][:components][0][:focal] = 'yes' })
    ]
    invalid.each { |data| expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error) }
  end

  it 'keeps the packaged Ruby and strict JSON examples identical' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = eval(File.read(File.join(root, 'high_level.rb'), encoding: 'UTF-8'), binding, File.join(root, 'high_level.rb'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'high_level.json'), encoding: 'UTF-8'))
    expect(json.to_svg(id: 'high-level-parity')).to eq(ruby.to_svg(id: 'high-level-parity'))
  end

  it 'aligns every node center with its measured phase chevron and keeps containment honest' do
    scene = reference_stack.layout
    expect(scene.width).to eq(1000)
    expect(scene.banners.size).to eq(4)
    expect(scene.banners.sum { |item| item[:rect][2] - item[:rect][0] }).to eq(964)
    expect(scene.banners.map { |item| item[:rect][2] - item[:rect][0] }).to all(satisfy { |width| width >= 192 && (width % 4).zero? })
    scene.boxes.each do |box|
      banner = scene.banners.find { |item| item[:phase].id == box.node.phase }
      expect(box.center[0]).to eq(banner[:cx])
      container = box.node.is_a?(SlimGraphR::HighLevelSource) ? scene.source_zone[:rect] : scene.cluster[:rect]
      expect(container[0]).to be <= box.x
      expect(container[1]).to be <= box.y
      expect(container[2]).to be >= box.right
      expect(container[3]).to be >= box.bottom
    end
    expect(scene.source_zone[:rect][2]).to be < scene.cluster[:rect][0]
    expect(SlimGraphR::Layout::Geometry.overlaps?(scene.source_zone[:rect], scene.cluster[:rect])).to be(false)
  end

  it 'pairs orchestration and crosscuts with the reserved right strip and grows footer geometry' do
    graph = reference_stack
    scene = graph.layout
    expect(scene.effective_width).to eq(964)
    expect(scene.verticals.map { |item| [item[:concern], item[:kind], item[:owner].id] }).to eq([
      ['Orchestration', :orchestration, 'airflow'], ['Security', :crosscut, 'identity']
    ])
    expect(scene.verticals.map { |item| item[:rect][0] }.uniq).to eq([972])
    expect(scene.verticals.map { |item| item[:rect][2] }.uniq).to eq([1000])
    expect(scene.verticals.each_cons(2).all? { |left, right| left[:rect][3] == right[:rect][1] }).to be(true)
    expect(scene.orchestration[:rect]).to eq([scene.cluster[:rect][0] + 12, 52, 952, 96])
    expect(scene.footers.first[:rect]).to eq([4, 388, 964, 428])
    expect(scene.legend_rect[1]).to be > scene.footers.last[:rect][3]
    expect(scene.legend_rect[3]).to be <= scene.height

    without_concerns = SlimGraphR.diagram(:high_level) do
      phase(:source) { source :a, type: :api }
      phase(:middle) { component :b, role: 'APP', focal: true }
      phase(:end) { component :c, role: 'OUT' }
      connect :a, :b
      connect :b, :c
    end.layout
    expect(without_concerns.effective_width).to eq(1000)
    expect(without_concerns.verticals).to be_empty
    expect(without_concerns.banners.last[:rect][2]).to eq(1000)
  end

  it 'routes forward links and trigger drops with reserved ports and visible arrow bodies' do
    scene = reference_stack.layout
    expect(scene.routes.map(&:style)).to eq(%i[secondary secondary primary primary trigger trigger trigger])
    scene.routes.each do |route|
      expect(route.points.size - 2).to be <= 2
      expect(route.points.each_cons(2).all? { |left, right| left[0] == right[0] || left[1] == right[1] }).to be(true)
      final_length = (route.points[-2][0] - route.points[-1][0]).abs + (route.points[-2][1] - route.points[-1][1]).abs
      expect(final_length).to be >= 16
      if route.style == :trigger
        target = scene.boxes.find { |box| box.node.id == route.edge.to }
        expect(route.points.first[1]).to eq(scene.orchestration[:rect][3])
        expect(route.points.last[1]).to eq(target.y)
        expect(route.points.first[0]).to eq(route.points.last[0])
      else
        source = scene.boxes.find { |box| box.node.id == route.edge.from }
        target = scene.boxes.find { |box| box.node.id == route.edge.to }
        expect(route.points.first[0]).to eq(source.right)
        expect(route.points.last[0]).to eq(target.x)
      end
    end
    nifi_ports = scene.routes.select { |route| route.edge.to == 'nifi' && route.style != :trigger }.map { |route| route.points.last[1] }.sort
    expect(nifi_ports.each_cons(2).map { |a, b| b - a }).to all(be >= 16)
    focal_trigger = scene.routes.find { |route| route.style == :trigger && route.edge.to == 'minio' }
    expect(focal_trigger.style).to eq(:trigger)
  end

  it 'renders semantic regions, topology-owned markers, z-order and the effective legend' do
    svg = reference_stack.to_svg(id: 'high-level-reference')
    expect(svg).to include('data-sgr-high-level="true"', 'data-sgr-source-zone="true"', 'stroke-dasharray="6 3"')
    expect(svg).to include('data-sgr-cluster="Kubernetes"', '>Kubernetes<')
    expect(svg).to include('data-sgr-source-type="db"', '>EXT · DB<')
    expect(svg).to include('data-sgr-component="minio"', 'data-sgr-focal="true"')
    expect(svg).to include('data-sgr-orchestration="airflow"', 'data-sgr-crosscut="identity"')
    expect(svg).to include('data-sgr-vertical-concern="Orchestration"', 'data-sgr-vertical-concern="Security"')
    expect(svg).to include('data-sgr-high-level-style="primary"', 'marker-end="url(#high-level-reference-arrow-accent)"')
    expect(svg).to include('data-sgr-high-level-style="secondary"', 'marker-end="url(#high-level-reference-arrow)"')
    expect(svg).to include('data-sgr-high-level-style="trigger"', 'stroke-dasharray="4 3"', 'marker-end="url(#high-level-reference-arrow-sm)"')
    expect(svg).to include('data-sgr-legend-kind="primary"', 'data-sgr-legend-kind="secondary"', 'data-sgr-legend-kind="trigger"')
    expect(svg.index('data-sgr-connector=')).to be < svg.index('data-sgr-component=')
  end

  it 'retains source types, focal and cross-spanning semantics in the accessible description' do
    svg = reference_stack.to_svg(id: 'high-level-accessible')
    expect(svg).to include('High-level data stack.', 'Cluster: Kubernetes.', 'PostgreSQL, db source: Registry')
    expect(svg).to include('MinIO, STORE, focal', 'Airflow orchestrates NiFi, MinIO, Superset')
    expect(svg).to include('Security concern: Identity: LDAP · OIDC')
  end

  it 'replaces the generated description with the supplied description' do
    svg = reference_stack(description: 'Author only <&>').to_svg(id: 'author-description')
    expect(svg[/<desc[^>]*>(.*?)<\/desc>/m, 1]).to eq('Author only &lt;&amp;&gt;')
  end

  it 'describes effective data and trigger styles including the focal trigger exception' do
    svg = reference_stack.to_svg(id: 'effective-description')
    description = svg[/<desc[^>]*>(.*?)<\/desc>/m, 1]
    expect(description).to include('PostgreSQL to NiFi: secondary', 'NiFi to MinIO: primary',
                                 'MinIO to Superset: primary', 'Airflow to MinIO: trigger')
    expect(description).not_to include('Airflow to MinIO: primary')
  end

  ['ß' * 45, 'A' * 40].each do |label|
    it "rejects a phase label whose rendered uppercase/spacing exceeds its banner (#{label[0]})" do
      data = json_data
      data[:phases][0][:label] = label
      graph = SlimGraphR::Document.from_json(JSON.generate(data))
      expect { graph.to_svg }.to raise_error(SlimGraphR::LayoutError, /phase label.*does not fit.*shorten/i)
    end
  end

  ['ß' * 42, 'A' * 70].each do |concern|
    it "rejects a rotated concern whose rendered uppercase/spacing exceeds its strip (#{concern[0]})" do
      data = json_data.merge(crosscuts: [])
      data[:orchestration][:concern] = concern
      graph = SlimGraphR::Document.from_json(JSON.generate(data))
      expect { graph.to_svg }.to raise_error(SlimGraphR::LayoutError, /vertical concern.*does not fit.*shorten/i)
    end
  end

  it 'preserves authored Unicode and frozen model strings while rendering fitted uppercase labels' do
    phase_label = +'Straße'
    concern = +'Straße'
    graph = SlimGraphR.diagram(:high_level) do
      phase(:source, phase_label) { source :a, type: :api }
      phase(:middle) { component :b, role: 'APP', focal: true }
      phase(:end) { component :c, role: 'OUT' }
      crosscut :identity, concern: concern
    end
    expect(graph.to_svg).to include('>STRASSE<')
    expect([phase_label, concern, graph.phases.first.label, graph.crosscuts.first.concern]).to all(eq('Straße'))
    expect(graph.phases.first.label).to be_frozen
    expect(graph.crosscuts.first.concern).to be_frozen
  end

  it 'rejects cluster headings that exceed the cluster width' do
    expect { reference_stack(cluster: 'W' * 150).to_svg }.to raise_error(
      SlimGraphR::LayoutError, /cluster label.*does not fit.*shorten/i
    )
  end

  it 'renders all style and theme combinations without changing measured geometry' do
    reference = reference_stack.layout
    SlimGraphR::Style.names.product(%i[light dark auto]).each do |style, theme|
      graph = reference_stack.with(style: style, theme: theme)
      expect(graph.layout).to eq(reference)
      svg = graph.to_svg(id: "high-level-#{style}-#{theme}")
      expect(svg).to include("data-sgr-style=\"#{style}\"", "data-sgr-theme=\"#{theme}\"")
      expect(svg.scan('data-sgr-high-level-phase=').size).to eq(4)
    end
  end

  it 'raises actionable layout errors instead of clipping fixed high-level boxes' do
    graph = SlimGraphR.diagram(:high_level) do
      phase(:source) { source :a, 'A' * 80, type: :api }
      phase(:middle) { component :b, role: 'APP', focal: true }
      phase(:end) { component :c, role: 'OUT' }
    end
    expect { graph.layout }.to raise_error(SlimGraphR::LayoutError, /source label.*does not fit.*shorten/i)
  end
end
