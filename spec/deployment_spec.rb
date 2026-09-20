require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'Deployment diagrams' do
  def network_path(svg, from, to)
    svg.match(/<path [^>]*data-sgr-network="#{from}-#{to}"[^>]*\/>/).to_s
  end

  def reference_deployment
    SlimGraphR.diagram(:deployment, title: 'Production placement') do
      zone :edge, 'Edge' do
        cdn :front_door, 'Global CDN', replicas: 2 do
          artifact 'storefront', version: '2026.09.1'
        end
      end
      zone :app, 'Production / eu-west-1' do
        pod :api, 'API pods', replicas: 3 do
          artifact 'api', version: 'v2.4.1'
          artifact 'otel sidecar', version: '0.109.0'
        end
        vm :jobs, 'Job runner' do
          artifact 'worker', version: 'v2.4.1'
        end
      end
      zone :data, 'Private data' do
        managed :primary, 'RDS primary', emphasis: true do
          artifact 'postgres', version: '16.4'
        end
        managed :standby, 'RDS standby' do
          artifact 'postgres', version: '16.4'
        end
      end

      network :front_door, :api, protocol: 'HTTPS', port: 443
      network :api, :jobs, protocol: 'HTTP', port: 9292
      network :api, :primary, protocol: 'TLS', port: 5432
      network :primary, :standby, protocol: 'Postgres', port: 5432, async: true, emphasis: true
    end
  end

  let(:json_data) do
    {
      type: 'deployment', title: 'Production placement',
      zones: [
        { id: 'edge', label: 'Edge', nodes: [
          { id: 'front_door', label: 'Global CDN', kind: 'cdn', replicas: 2,
            artifacts: [{ name: 'storefront', version: '2026.09.1' }] }
        ] },
        { id: 'app', label: 'Production / eu-west-1', nodes: [
          { id: 'api', label: 'API pods', kind: 'pod', replicas: 3,
            artifacts: [{ name: 'api', version: 'v2.4.1' }, { name: 'otel sidecar', version: '0.109.0' }] },
          { id: 'jobs', label: 'Job runner', kind: 'vm',
            artifacts: [{ name: 'worker', version: 'v2.4.1' }] }
        ] },
        { id: 'data', label: 'Private data', nodes: [
          { id: 'primary', label: 'RDS primary', kind: 'managed', emphasis: true,
            artifacts: [{ name: 'postgres', version: '16.4' }] },
          { id: 'standby', label: 'RDS standby', kind: 'managed',
            artifacts: [{ name: 'postgres', version: '16.4' }] }
        ] }
      ],
      paths: [
        { from: 'front_door', to: 'api', protocol: 'HTTPS', port: 443 },
        { from: 'api', to: 'jobs', protocol: 'HTTP', port: 9292 },
        { from: 'api', to: 'primary', protocol: 'TLS', port: 5432 },
        { from: 'primary', to: 'standby', protocol: 'Postgres', port: 5432, async: true, emphasis: true }
      ]
    }
  end

  it 'builds structural zone, infrastructure, artifact and network records' do
    graph = reference_deployment
    expect(graph.direction).to eq(:right)
    expect(graph.zones.map(&:id)).to eq(%w[edge app data])
    expect(graph.nodes.map { |node| [node.id, node.zone, node.kind, node.replicas] }).to include(
      ['front_door', 'edge', :cdn, 2], ['api', 'app', :pod, 3], ['primary', 'data', :managed, 1]
    )
    expect(graph.nodes.find { |node| node.id == 'api' }.artifacts.map { |item| [item.name, item.version] }).to eq(
      [['api', 'v2.4.1'], ['otel sidecar', '0.109.0']]
    )
    expect(graph.edges.last.to_h).to include(
      from: 'primary', to: 'standby', protocol: 'Postgres', port: 5432, dashed: true, emphasis: true
    )
  end

  it 'supports every infrastructure constructor and freezes the nested model' do
    graph = SlimGraphR.diagram(:deployment) do
      zone :prod do
        host :bare_metal do
          artifact 'app', version: '1.0'
        end
      end
    end
    expect(graph.nodes.first.kind).to eq(:host)
    expect([graph.zones, graph.nodes, graph.nodes.first.artifacts, graph.edges]).to all(be_frozen)
    expect([graph.zones.first, graph.nodes.first, graph.nodes.first.artifacts.first]).to all(be_frozen)
  end

  it 'parses strict JSON into exactly the same model and SVG' do
    parsed = SlimGraphR::Document.from_json(JSON.generate(json_data))
    expect(parsed.zones.map(&:to_h)).to eq(reference_deployment.zones.map(&:to_h))
    expect(parsed.nodes.map(&:to_h)).to eq(reference_deployment.nodes.map(&:to_h))
    expect(parsed.edges.map(&:to_h)).to eq(reference_deployment.edges.map(&:to_h))
    expect(parsed.to_svg(id: 'deployment-parity')).to eq(reference_deployment.to_svg(id: 'deployment-parity'))
  end

  it 'keeps the standalone Ruby and JSON examples equivalent' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = eval(File.read(File.join(root, 'deployment.rb')), binding, File.join(root, 'deployment.rb'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'deployment.json')))
    expect(json.to_svg(id: 'deployment-example-parity')).to eq(ruby.to_svg(id: 'deployment-example-parity'))
  end

  it 'keeps infrastructure structurally inside zones and deployment vocabulary exclusive' do
    expect { SlimGraphR.diagram(:deployment) { pod :api } }.to raise_error(SlimGraphR::Error, /inside a zone/i)
    expect { SlimGraphR.diagram(:deployment) { zone(:prod) { artifact 'api', version: '1' } } }.to raise_error(SlimGraphR::Error, /inside an infrastructure/i)
    expect { SlimGraphR.diagram(:deployment) { zone(:prod) { pod(:api) } } }.to raise_error(SlimGraphR::Error, /artifact/i)
    expect { SlimGraphR.diagram(:deployment) { node :api } }.to raise_error(SlimGraphR::Error, /host.*pod.*managed.*cdn/i)
    expect { SlimGraphR.diagram(:deployment) { edge :a, :b } }.to raise_error(SlimGraphR::Error, /network/i)
    expect { SlimGraphR.diagram(:deployment, direction: :down) { zone(:prod) { pod(:api) { artifact 'api', version: '1' } } } }.to raise_error(SlimGraphR::Error, /fixed :right direction/i)
    expect do
      SlimGraphR.diagram(:deployment) { zone(:outer) { zone(:inner) {} } }
    end.to raise_error(SlimGraphR::Error, /zones cannot nest/i)
    expect do
      SlimGraphR.diagram(:deployment) do
        zone(:prod) { pod(:api) { pod(:nested) { artifact 'x', version: '1' } } }
      end
    end.to raise_error(SlimGraphR::Error, /Infrastructure nodes cannot nest/)
    recovered = SlimGraphR.diagram(:deployment) do
      zone :prod do
        begin
          zone(:nested) {}
        rescue SlimGraphR::Error
        end
        pod :api do
          begin
            vm(:nested) {}
          rescue SlimGraphR::Error
          end
          artifact 'api', version: '1'
        end
      end
    end
    expect(recovered.nodes.first.artifacts.first.name).to eq('api')
    interleaved = SlimGraphR.diagram(:deployment) do
      zone(:a) { pod(:one) { artifact 'one', version: '1' } }
      network :one, :two, protocol: 'HTTP', port: 80
      zone(:b) { pod(:two) { artifact 'two', version: '1' } }
    end
    expect(interleaved.edges.first.label).to eq('HTTP:80')
  end

  it 'rejects invalid values, duplicates, references and shared focal excess in Ruby' do
    valid = ->(&extra) do
      SlimGraphR.diagram(:deployment) do
        zone :prod do
          pod :api, replicas: 2 do
            artifact 'api', version: '1.0'
          end
          pod :worker do
            artifact 'worker', version: '1.0'
          end
        end
        instance_eval(&extra) if extra
      end
    end
    expect { SlimGraphR.diagram(:deployment) { zone('') {} } }.to raise_error(SlimGraphR::Error, /Zone IDs must not be blank/)
    expect { SlimGraphR.diagram(:deployment) { zone(:empty) {} } }.to raise_error(SlimGraphR::Error, /Zone empty is empty/)
    expect { SlimGraphR.diagram(:deployment) { zone(:a) { pod(:x) { artifact 'api', version: '' } } } }.to raise_error(SlimGraphR::Error, /version.*blank/i)
    [-1, 0, 1.5, true, '2'].each { |value| expect { SlimGraphR.diagram(:deployment) { zone(:a) { pod(:x, replicas: value) { artifact 'x', version: '1' } } } }.to raise_error(SlimGraphR::Error, /replicas.*positive integer/i) }
    expect { valid.call { network :api, :worker, protocol: '', port: 443 } }.to raise_error(SlimGraphR::Error, /protocol.*blank/i)
    [nil, 0, 65_536, 443.0, true, '443'].each { |value| expect { valid.call { network :api, :worker, protocol: 'HTTP', port: value } }.to raise_error(SlimGraphR::Error, /port.*1.*65535/i) }
    expect { valid.call { network :api, :api, protocol: 'HTTP', port: 80 } }.to raise_error(SlimGraphR::Error, /itself/i)
    expect { valid.call { network :api, :missing, protocol: 'HTTP', port: 80 } }.to raise_error(SlimGraphR::Error, /Unknown infrastructure node: missing/)
    expect { valid.call { network :api, :worker, protocol: 'HTTP', port: 80; network :api, :worker, protocol: 'TLS', port: 443 } }.to raise_error(SlimGraphR::Error, /Duplicate network path/)
    expect do
      SlimGraphR.diagram(:deployment) do
        zone :prod do
          pod(:api) { artifact 'api', version: '1' }
          network :api, :other, protocol: 'HTTP', port: 80
        end
      end
    end.to raise_error(SlimGraphR::Error, /top level/i)
    expect do
      SlimGraphR.diagram(:deployment) do
        zone :prod do
          3.times { |i| pod("n#{i}", emphasis: true) { artifact "a#{i}", version: '1' } }
        end
      end
    end.to raise_error(SlimGraphR::Error, /two focal/i)

    expect do
      SlimGraphR.diagram(:deployment) do
        zone :prod do
          pod(:api, emphasis: true) { artifact 'api', version: '1' }
          pod(:worker, emphasis: true) { artifact 'worker', version: '1' }
        end
        network :api, :worker, protocol: 'HTTP', port: 80, emphasis: true
      end
    end.to raise_error(SlimGraphR::Error, /two focal/i)

    expect do
      SlimGraphR.diagram(:deployment) do
        zone :prod do
          pod(:api, emphasis: true) { artifact 'api', version: '1' }
          pod(:worker) { artifact 'worker', version: '1' }
          pod(:queue) { artifact 'queue', version: '1' }
        end
        network :api, :worker, protocol: 'HTTP', port: 80, emphasis: true
        network :worker, :queue, protocol: 'AMQP', port: 5672, emphasis: true
      end
    end.to raise_error(SlimGraphR::Error, /two focal/i)
  end

  it 'keeps zone and node IDs globally unique' do
    expect do
      SlimGraphR.diagram(:deployment) do
        zone(:same) { pod(:one) { artifact 'a', version: '1' } }
        zone(:same) { pod(:two) { artifact 'b', version: '1' } }
      end
    end.to raise_error(SlimGraphR::Error, /Zone IDs.*unique/)
    expect do
      SlimGraphR.diagram(:deployment) do
        zone(:a) { pod(:same) { artifact 'a', version: '1' } }
        zone(:b) { vm(:same) { artifact 'b', version: '1' } }
      end
    end.to raise_error(SlimGraphR::Error, /node IDs.*unique/)
    expect do
      SlimGraphR.diagram(:deployment) do
        zone(:shared) { pod(:shared) { artifact 'a', version: '1' } }
      end
    end.to raise_error(SlimGraphR::Error, /share one namespace/)
  end

  it 'enforces the deployment budgets' do
    expect do
      SlimGraphR.diagram(:deployment) do
        4.times { |i| zone("z#{i}") { pod("n#{i}") { artifact "a#{i}", version: '1' } } }
      end
    end.to raise_error(SlimGraphR::Error, /three zones/i)
    expect do
      SlimGraphR.diagram(:deployment) do
        zone(:prod) { 7.times { |i| pod("n#{i}") { artifact "a#{i}", version: '1' } } }
      end
    end.to raise_error(SlimGraphR::Error, /six infrastructure/i)
    expect do
      SlimGraphR.diagram(:deployment) do
        zone(:prod) { pod(:api) { 10.times { |i| artifact "a#{i}", version: '1' } } }
      end
    end.to raise_error(SlimGraphR::Error, /nine artifact/i)
    expect do
      SlimGraphR.diagram(:deployment) do
        zone(:prod) { 5.times { |i| pod("n#{i}") { artifact "a#{i}", version: '1' } } }
        [[0, 1], [0, 2], [0, 3], [0, 4], [1, 0], [1, 2], [1, 3], [1, 4], [2, 0]].each_with_index do |(from, to), i|
          network "n#{from}", "n#{to}", protocol: "P#{i}", port: i + 1
        end
      end
    end.to raise_error(SlimGraphR::Error, /eight network/i)
  end

  it 'rejects unknown, cross-type, null and wrongly typed JSON fields' do
    invalid = [
      json_data.merge(nodes: []),
      json_data.merge(edges: []),
      json_data.merge(groups: []),
      json_data.merge(zones: nil),
      json_data.merge(zones: [{ id: 'z', label: 'Z', nodes: [] }]),
      json_data.merge(zones: [{ id: 'z', label: 'Z', nodes: [{ id: 'n', kind: 'service', artifacts: [{ name: 'a', version: '1' }] }] }]),
      json_data.merge(zones: [{ id: 'z', label: 'Z', nodes: [{ id: 'n', kind: 'pod', replicas: false, artifacts: [{ name: 'a', version: '1' }] }] }]),
      json_data.merge(paths: [{ from: 'front_door', to: 'api', protocol: 'HTTPS', port: 443, async: 'yes' }]),
      json_data.merge(paths: [{ from: 'front_door', to: 'api', protocol: 'HTTPS', port: nil }]),
      json_data.merge(zones: [{ id: 'z', label: 'Z', nodes: [{ id: 'n', kind: 'pod', artifacts: [{ name: 'a', version: nil }] }] }]),
      json_data.merge(zones: [{ id: 'z', label: 'Z', typo: true, nodes: [] }])
    ]
    invalid.each { |data| expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error) }
  end

  it 'measures zones, nodes, artifact chips and route labels without collisions' do
    scene = reference_deployment.layout
    contains = ->(outer, inner) do
      outer[0] <= inner[0] && outer[1] <= inner[1] && outer[2] >= inner[2] && outer[3] >= inner[3]
    end
    expect(scene.zones.size).to eq(3)
    expect(scene.boxes.size).to eq(5)
    expect(scene.routes.size).to eq(4)
    scene.zones.each do |zone|
      members = scene.boxes.select { |box| box.node.zone == zone[:id] }
      expect(members).not_to be_empty
      expect(contains.call(zone[:rect], zone[:header_rect])).to be(true)
      members.each { |box| expect(contains.call(zone[:rect], box.rect)).to be(true) }
      expect(zone[:header_rect][3]).to be <= members.map(&:y).min
      expect(members.map(&:y).min - zone[:rect][1]).to eq(40)
    end
    scene.boxes.combination(2) do |left, right|
      expect(SlimGraphR::Layout::Geometry.overlaps?(left.rect, right.rect)).to be(false)
    end
    scene.boxes.each do |box|
      expect(box.artifacts.size).to eq(box.node.artifacts.size)
      expect(contains.call(box.rect, box.type_tag[:rect])).to be(true)
      if box.node.replicas > 1
        expect(contains.call(box.rect, box.replica_badge[:rect])).to be(true)
        expect(SlimGraphR::Layout::Geometry.overlaps?(box.type_tag[:rect], box.replica_badge[:rect])).to be(false)
      else
        expect(box.replica_badge).to be_nil
      end
      expect(SlimGraphR::Text.width(box.node.label, 14)).to be <= box.width - 24
      box.artifacts.each do |chip|
        expect(contains.call(box.rect, chip[:rect])).to be(true)
        expect(chip[:rect][3] - chip[:rect][1]).to eq(24)
        name_right = chip[:name_x] + SlimGraphR::Text.width(chip[:artifact].name, 12)
        version_left = chip[:version_x] - SlimGraphR::Text.width(chip[:artifact].version, 9, font: :mono)
        expect(name_right + 12).to be <= version_left
      end
      gaps = box.artifacts.map { |chip| chip[:rect] }.each_cons(2).map { |a, b| b[1] - a[3] }
      expect(gaps).to all(eq(8))
    end
    scene.routes.each do |route|
      expect(route.label_box[:lines]).to eq(["#{route.edge.protocol}:#{route.edge.port}"])
      expect(route.label_box[:rect][2] - route.label_box[:rect][0]).to eq(SlimGraphR::Text.grid(SlimGraphR::Text.width(route.edge.label, 8, font: :mono) + 16))
      (scene.boxes.map(&:rect) + scene.zones.map { |zone| zone[:header_rect] }).each do |rect|
        expect(SlimGraphR::Layout::Geometry.overlaps?(route.label_box[:rect], rect)).to be(false)
      end
      route.points.each_cons(2) do |a, b|
        label = route.label_box[:rect]
        clearance = [label[0] - 6, label[1] - 6, label[2] + 6, label[3] + 6]
        expect(SlimGraphR::Layout::Geometry.blocked?(a, b, clearance)).to be(false)
        scene.zones.each { |zone| expect(SlimGraphR::Layout::Geometry.blocked?(a, b, zone[:header_rect])).to be(false) }
      end
      scene.boxes.reject { |box| [route.edge.from, route.edge.to].include?(box.node.id) }.each do |box|
        route.points.each_cons(2) { |a, b| expect(SlimGraphR::Layout::Geometry.blocked?(a, b, box.rect)).to be(false) }
      end
      source = scene.boxes.find { |box| box.node.id == route.edge.from }
      target = scene.boxes.find { |box| box.node.id == route.edge.to }
      on_boundary = ->(point, box) do
        ((point[0] == box.x || point[0] == box.right) && point[1].between?(box.y, box.bottom)) ||
          ((point[1] == box.y || point[1] == box.bottom) && point[0].between?(box.x, box.right))
      end
      expect(on_boundary.call(route.points.first, source)).to be(true)
      expect(on_boundary.call(route.points.last, target)).to be(true)
      expect((route.points[-2][0] - route.points[-1][0]).abs + (route.points[-2][1] - route.points[-1][1]).abs).to be >= 16
    end
    scene.routes.map(&:label_box).combination(2) do |left, right|
      expect(SlimGraphR::Layout::Geometry.overlaps?(left[:rect], right[:rect])).to be(false)
    end
    scene.routes.combination(2) do |left, right|
      left.points.each_cons(2) do |a, b|
        right.points.each_cons(2) do |c, d|
          expect(SlimGraphR::Layout::Geometry.parallel_conflict?(a, b, c, d)).to be(false)
        end
      end
    end
  end

  it 'routes a reverse cross-zone async path from the authored source boundary' do
    graph = SlimGraphR.diagram(:deployment) do
      zone(:left) { host(:one) { artifact 'one', version: '1' } }
      zone(:right) { vm(:two) { artifact 'two', version: '2' } }
      network :two, :one, protocol: 'SYNC', port: 7443, async: true
    end
    scene = graph.layout
    route = scene.routes.first
    source = scene.boxes.find { |box| box.node.id == 'two' }
    target = scene.boxes.find { |box| box.node.id == 'one' }
    expect(route.points.first[0]).to eq(source.x)
    expect(route.points.last[0]).to eq(target.right)
    path = network_path(graph.to_svg(id: 'reverse-deployment'), 'two', 'one')
    expect(path).to include('data-sgr-network-scope="cross-zone"', 'data-sgr-network-async="true"',
                            'stroke="var(--sgr-link)"', 'stroke-dasharray="5 4"',
                            'marker-end="url(#reverse-deployment-arrow-link-open)"')
  end

  it 'omits replica badges for one instance while preserving counted replica badges' do
    svg = reference_deployment.to_svg(id: 'replica-counts')
    expect(svg).not_to include('data-sgr-replicas="1"', '>x1<')
    expect(svg).to include('data-sgr-replicas="2"', '>x2<', 'data-sgr-replicas="3"', '>x3<')
  end

  it 'renders protocol and port labels at the reference 8px size' do
    expect(reference_deployment.to_svg(id: 'network-type')).to include('.sgr-network-label{font-size:8px}')
  end

  it 'gives a minimal reciprocal cross-zone pair clear labels and directed attachments' do
    graph = SlimGraphR.diagram(:deployment) do
      zone(:left) { host(:one) { artifact 'one', version: '1' } }
      zone(:right) { vm(:two) { artifact 'two', version: '2' } }
      network :one, :two, protocol: 'P0', port: 1
      network :two, :one, protocol: 'P1', port: 2, async: true
    end
    scene = graph.layout
    scene.routes.each do |route|
      label = route.label_box[:rect]
      padded = [label[0] - 8, label[1] - 8, label[2] + 8, label[3] + 8]
      other = scene.routes.find { |candidate| candidate != route }
      other.points.each_cons(2) do |a, b|
        expect(SlimGraphR::Layout::Geometry.blocked?(a, b, padded)).to be(false)
      end
      expect(SlimGraphR::Layout::Geometry.overlaps?(padded, other.label_box[:rect])).to be(false)
      source = scene.boxes.find { |box| box.node.id == route.edge.from }
      target = scene.boxes.find { |box| box.node.id == route.edge.to }
      expect(route.points.first[0]).to eq(source.node.id == 'one' ? source.right : source.x)
      expect(route.points.last[0]).to eq(target.node.id == 'one' ? target.right : target.x)
    end
    svg = graph.to_svg(id: 'reciprocal')
    expect(svg).to include('>P0:1<', '>P1:2<')
    expect(network_path(svg, 'two', 'one')).to include('marker-end="url(#reciprocal-arrow-link-open)"')
  end

  it 'renders placement semantics, z-order, path treatments and descriptions in every style and mode' do
    SlimGraphR::Style.names.product(%i[light dark auto]).each do |style, theme|
      svg = reference_deployment.with(style: style, theme: theme).to_svg(id: "deployment-#{style}-#{theme}")
      expect(svg.scan('data-sgr-deployment-zone=').size).to eq(3)
      expect(svg.scan('data-sgr-infrastructure=').size).to eq(5)
      expect(svg.scan('data-sgr-artifact=').size).to eq(6)
      expect(svg).to include('data-sgr-replicas="3"', '>x3<', '>v2.4.1<', '>HTTPS:443<', '>Postgres:5432<')
      edge_path = network_path(svg, 'front_door', 'api')
      internal_path = network_path(svg, 'api', 'jobs')
      database_path = network_path(svg, 'api', 'primary')
      replication_path = network_path(svg, 'primary', 'standby')
      expect(edge_path).to include('data-sgr-network-scope="cross-zone"', 'data-sgr-network-async="false"',
                                   'stroke="var(--sgr-link)"', "marker-end=\"url(#deployment-#{style}-#{theme}-arrow-link)\"")
      expect(internal_path).to include('data-sgr-network-scope="internal"', 'stroke="var(--sgr-muted)"',
                                       "marker-end=\"url(#deployment-#{style}-#{theme}-arrow)\"")
      expect(database_path).to include('data-sgr-network-scope="cross-zone"', 'stroke="var(--sgr-link)"')
      expect(replication_path).to include('data-sgr-network-scope="internal"', 'data-sgr-network-async="true"',
                                          'data-sgr-network-emphasis="true"', 'stroke="var(--sgr-accent)"',
                                          'stroke-width="1.6"', 'stroke-dasharray="5 4"',
                                          "marker-end=\"url(#deployment-#{style}-#{theme}-arrow-accent-open)\"")
      expect(svg.index('data-sgr-deployment-zone=')).to be < svg.index('data-sgr-connector=')
      expect(svg.index('data-sgr-connector=')).to be < svg.index('data-sgr-network-label=')
      expect(svg.index('data-sgr-network-label=')).to be < svg.index('data-sgr-infrastructure=')
      expect(svg).to include('Edge contains Global CDN with 2 replicas: storefront 2026.09.1')
      expect(svg).to include('Global CDN to API pods over HTTPS:443, cross-zone')
    end
  end
end
