# frozen_string_literal: true
require 'spec_helper'
require 'json'
require_relative '../lib/slim_graph_r/document'

RSpec.describe 'UML class diagrams' do
  def build(style: :editorial, theme: :light, description: nil, &block)
    SlimGraphR.diagram(:uml_class, title: 'Checkout objects', style: style, theme: theme, description: description, &block)
  end

  def representative(style: :editorial, theme: :light)
    build(style: style, theme: theme) do
      interface :payable, 'Payable' do
        operation '+ authorize(amount: Money): Receipt'
      end
      abstract_class :payment, 'Payment', focal: true do
        attribute '- reference: String'
        operation '+ capture(): Receipt'
      end
      class_type :card_payment, 'CardPayment' do
        attribute '- token: String'
        operation '+ authorize(amount: Money): Receipt'
      end
      relation :card_payment, :payment, kind: :inheritance
      relation :card_payment, :payable, kind: :realization
    end
  end

  it 'fits the exact atlas checkout model in the desktop content column without disturbing routes' do
    graph = build do
      interface(:payable, 'Payable') { operation '+ authorize(amount: Money): Receipt' }
      abstract_class(:payment, 'Payment', focal: true) do
        attribute '- reference: String'
        operation '+ capture(): Receipt'
      end
      class_type(:card_payment, 'CardPayment') { attribute '- token: String' }
      relation :card_payment, :payment, kind: :inheritance
      relation :card_payment, :payable, kind: :realization
    end

    scene = graph.layout
    expect(scene.width).to eq(900)
    expect(graph.to_svg(id: 'atlas-uml')).to include('viewBox="0 0 900 ', 'width="1350"', 'min-width:1350px')
    scene.routes.each do |route|
      route.points.each_cons(2) { |a, b| expect(a[0] == b[0] || a[1] == b[1]).to be(true) }
      expect(route.points).to all(satisfy { |x, y| x.between?(0, scene.width) && y.between?(0, scene.height) })
    end
  end

  it 'keeps literal immutable class/member records and omits unauthored compartments' do
    graph = representative
    expect(graph.classes.map(&:kind)).to eq(%i[interface abstract_class class])
    expect(graph.classes.last.attributes).to eq(['- token: String'])
    expect(graph.classes.last.operations).to eq(['+ authorize(amount: Money): Receipt'])
    expect(graph.classes.first.attributes).to eq([])
    expect(graph.classes).to be_frozen
    expect(graph.classes).to all(be_frozen)
    expect(graph.classes.flat_map { |item| [item.attributes, item.operations] }).to all(be_frozen)
    expect(graph.relations).to be_frozen
    expect(graph.relations).to all(be_frozen)
    expect { graph.classes.last.attributes << '+ inferred(): String' }.to raise_error(FrozenError)
  end

  it 'requires explicit relationship meaning without parsing member text' do
    expect do
      build do
        class_type(:a, 'A') { attribute 'owner: B' }
        class_type :b, 'B'
      end
    end.to raise_error(SlimGraphR::Error, /one to eight relations/i)
    expect do
      build do
        class_type :a, 'A'
        class_type :b, 'B'
        relation :a, :b, kind: :composition
      end
    end.to raise_error(SlimGraphR::Error, /owner/i)
    expect do
      build do
        class_type :a, 'A'
        class_type :b, 'B'
        relation :a, :b, kind: :association
      end
    end.to raise_error(SlimGraphR::Error, /multiplic/i)
  end

  it 'accepts exactly six kinds with endpoint ownership and association multiplicity identity' do
    graph = build do
      %i[a b c d e f g].each { |id| class_type id, id.to_s.upcase }
      relation :a, :b, kind: :inheritance
      relation :b, :c, kind: :realization
      relation :c, :d, kind: :composition, owner: :d
      relation :d, :e, kind: :aggregation, owner: :d
      relation :e, :f, kind: :association, from_multiplicity: '0..*', to_multiplicity: '1..*'
      relation :f, :g, kind: :dependency
    end
    expect(graph.relations.map(&:kind)).to eq(%i[inheritance realization composition aggregation association dependency])
    association = graph.relations[4]
    expect([association.from_multiplicity, association.to_multiplicity]).to eq(['0..*', '1..*'])
    expect(graph.relations[2].owner).to eq('d')
  end

  it 'renders an authored relation label with a measured opaque mask and includes it in the description' do
    graph = build do
      class_type :service, 'Service'
      interface :contract, 'Contract'
      relation :service, :contract, kind: :dependency, label: 'USES'
    end
    expect(graph.relations.first.label).to eq('USES')
    expect(graph.to_svg(id: 'uml-label')).to include('data-sgr-relation-label="USES"', 'data-sgr-relation-label-mask="true"', 'depends on Contract (USES)')
  end

  it 'rejects unknown options, invalid enums, references, booleans, duplicates, and excess content' do
    invalid = [
      proc { build { class_type :a, 'A'; class_type :b, 'B'; relation :a, :b, kind: :bogus } },
      proc { build { class_type :a, 'A'; class_type :b, 'B'; relation :a, :c, kind: :dependency } },
      proc { build { class_type :a, 'A'; class_type :a, 'Again'; relation :a, :a, kind: :dependency } },
      proc { build { class_type :a, 'A', focal: 'yes'; class_type :b, 'B'; relation :a, :b, kind: :dependency } },
      proc { build { class_type :a, 'A', color: 'red'; class_type :b, 'B'; relation :a, :b, kind: :dependency } },
      proc { build { class_type(:a, 'A') { 6.times { |i| attribute "a#{i}" } }; class_type :b, 'B'; relation :a, :b, kind: :dependency } }
    ]
    invalid.each { |call| expect(&call).to raise_error(SlimGraphR::Error) }
  end

  it 'keeps the DSL type-local and rejects generic graph records' do
    expect { SlimGraphR.diagram(:architecture) { class_type :a, 'A' } }.to raise_error(SlimGraphR::Error, /only.*UML/i)
    expect { build { node :a, 'A'; node :b, 'B'; edge :a, :b } }.to raise_error(SlimGraphR::Error, /dedicated UML/i)
    expect do
      build do
        class_type(:a, 'A') { operation '+ ok()', visibility: :public }
        class_type :b, 'B'
        relation :a, :b, kind: :dependency
      end
    end.to raise_error(SlimGraphR::Error, /exactly one literal/i)
  end

  it 'parses strict JSON and gives fixed-ID parity in every style and light/dark theme' do
    path = File.expand_path('../examples/standalone/uml_class.json', __dir__)
    json = File.read(path, encoding: 'UTF-8')
    parsed = SlimGraphR::Document.from_json(json)
    expect(parsed.classes.map(&:to_h)).to eq(representative.classes.map(&:to_h))
    %i[editorial ruby blueprint mono].product(%i[light dark]).each do |style, theme|
      expect(parsed.with(style: style, theme: theme).to_svg(id: 'uml-fixed')).to eq(
        representative(style: style, theme: theme).to_svg(id: 'uml-fixed')
      )
    end
  end

  it 'rejects null, unknown, partial, malformed, and cross-family JSON fields' do
    path = File.expand_path('../examples/standalone/uml_class.json', __dir__)
    base = JSON.parse(File.read(path, encoding: 'UTF-8'))
    invalid = [
      base.merge('classes' => nil),
      base.merge('nodes' => []),
      base.merge('classes' => base['classes'].map(&:dup).tap { |items| items[0]['color'] = 'red' }),
      base.merge('relations' => [{ 'from' => 'card_payment', 'to' => 'payment', 'kind' => 'association', 'from_multiplicity' => '1' }]),
      base.merge('relations' => [{ 'from' => 'card_payment', 'to' => 'payment', 'kind' => 'composition' }])
    ]
    invalid.each { |data| expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error) }
  end

  it 'renders natural compartments, interface and abstract treatments, and readable physical text' do
    graph = representative
    scene = graph.layout
    heights = scene.boxes.to_h { |box| [box.class_record.id, box.height] }
    expect(heights.values.uniq.size).to be > 1
    expect(scene.boxes.find { |box| box.class_record.id == 'payable' }.attribute_rect).to be_nil
    svg = graph.to_svg(id: 'uml-geometry')
    expect(svg).to include('data-sgr-uml-class="true"', 'data-sgr-display-scale="1.5"', '«interface»')
    expect(svg).to include('data-sgr-uml-kind="abstract_class"', 'font-style:italic')
    expect(svg[/<path[^>]+data-sgr-relation-kind="inheritance"[^>]*>/]).to include('stroke="var(--sgr-accent)"', 'inheritance-triangle-accent')
    expect(svg[/<path[^>]+data-sgr-relation-kind="realization"[^>]*>/]).to include('stroke="var(--sgr-muted)"', 'realization-triangle)')
    expect(svg.scan('data-sgr-compartment="attributes"').size).to eq(2)
    expect(svg.scan('data-sgr-compartment="operations"').size).to eq(3)
  end

  it 'wraps long literal members into 18px lines and grows the authored compartment' do
    graph = build do
      class_type(:long, 'Long') { operation '+ authorize_a_deliberately_long_amount(amount: ExtremelySpecificMoney): ExtremelySpecificReceipt' }
      class_type :short, 'Short'
      relation :long, :short, kind: :dependency
    end
    box = graph.layout.boxes.first
    expect(box.operation_rows.first[:lines].size).to be > 1
    expect(box.operation_rows.first[:height]).to eq(box.operation_rows.first[:lines].size * 18)
    expect(graph.to_svg(id: 'uml-wrap').scan('data-sgr-member="+ authorize_a_deliberately_long_amount').size).to eq(box.operation_rows.first[:lines].size)
  end

  it 'defines every marker and legend kind while reserving the open arrow for dependency' do
    graph = build do
      %i[a b c d e f g].each { |id| class_type id, id.to_s.upcase }
      relation :a, :b, kind: :inheritance
      relation :b, :c, kind: :realization
      relation :c, :d, kind: :composition, owner: :c
      relation :d, :e, kind: :aggregation, owner: :e
      relation :e, :f, kind: :association, from_multiplicity: '1', to_multiplicity: '0..*'
      relation :f, :g, kind: :dependency
    end
    svg = graph.to_svg(id: 'uml-markers')
    %w[inheritance realization composition aggregation association dependency].each do |kind|
      expect(svg).to include(%(data-sgr-legend-kind="#{kind}"), %(data-sgr-relation-kind="#{kind}"))
    end
    association = svg[/<path[^>]+data-sgr-relation-kind="association"[^>]*>/]
    dependency = svg[/<path[^>]+data-sgr-relation-kind="dependency"[^>]*>/]
    expect(association).not_to include('marker-')
    expect(dependency).to include('marker-end="url(#uml-markers-dependency-arrow)"')
    expect(svg).to include('stroke-dasharray="5,4"', 'stroke-dasharray="4,3"')
  end

  it 'puts triangles on targets and diamonds at the declared owner, including reversed owners' do
    graph = build do
      %i[a b c d].each { |id| class_type id, id.to_s.upcase }
      relation :a, :b, kind: :inheritance
      relation :b, :c, kind: :composition, owner: :b
      relation :c, :d, kind: :aggregation, owner: :d
    end
    svg = graph.to_svg(id: 'uml-owner')
    expect(svg[/<path[^>]+data-sgr-relation-kind="inheritance"[^>]*>/]).to include('marker-end="url(#uml-owner-inheritance-triangle)"')
    expect(svg[/<path[^>]+data-sgr-relation-kind="composition"[^>]*>/]).to include('data-sgr-owner-end="from"', 'marker-start="url(#uml-owner-composition-diamond)"')
    expect(svg[/<path[^>]+data-sgr-relation-kind="aggregation"[^>]*>/]).to include('data-sgr-owner-end="to"', 'marker-end="url(#uml-owner-aggregation-diamond)"')
    expect(svg[/<marker id="uml-owner-composition-diamond"[^>]*>/]).to include('refX="13"', 'orient="auto-start-reverse"')
    graph.layout.routes.select { |route| %i[composition aggregation].include?(route.relation.kind) }.each do |route|
      owner_from = route.relation.owner == route.relation.from
      port = owner_from ? route.from_port : route.to_port
      neighbor = owner_from ? route.points[1] : route.points[-2]
      outward = port[:side] == :left ? neighbor[0] < port[:point][0] : neighbor[0] > port[:point][0]
      expect(outward).to be(true)
      expect((neighbor[0] - port[:point][0]).abs).to be >= 14
    end
  end

  it 'places association multiplicities at their exact authored endpoints with opaque masks' do
    graph = build do
      class_type :many, 'Many'
      class_type :one, 'One'
      relation :many, :one, kind: :association, from_multiplicity: '0..*', to_multiplicity: '1'
    end
    route = graph.layout.routes.first
    expect(route.from_port[:class_id]).to eq('many')
    expect(route.to_port[:class_id]).to eq('one')
    svg = graph.to_svg(id: 'uml-multiplicity')
    expect(svg).to include('data-sgr-multiplicity-end="from">0..*</text>', 'data-sgr-multiplicity-end="to">1</text>')
    expect(svg.scan('data-sgr-multiplicity-mask').size).to eq(2)
    expect(route.from_label[:y]).to eq(route.from_port[:point][1])
    expect(route.to_label[:y]).to eq(route.to_port[:point][1])
  end

  it 'keeps routes orthogonal, endpoints on actual card bounds, and cards clear' do
    graph = representative
    scene = graph.layout
    scene.routes.each do |route|
      route.points.each_cons(2) { |a, b| expect(a[0] == b[0] || a[1] == b[1]).to be(true) }
      from_box = scene.boxes.find { |box| box.class_record.id == route.relation.from }
      to_box = scene.boxes.find { |box| box.class_record.id == route.relation.to }
      expect([from_box.x, from_box.x + from_box.width]).to include(route.from_port[:point][0])
      expect([to_box.x, to_box.x + to_box.width]).to include(route.to_port[:point][0])
    end
  end

  it 'serializes orthogonal endpoint tangents and assigns independent exterior corridors' do
    graph = representative
    scene = graph.layout
    svg = graph.to_svg(id: 'uml-paths')
    scene.routes.each do |route|
      tag = svg[/<path[^>]+data-sgr-relation-kind="#{route.relation.kind}"[^>]*>/]
      path = tag[/ d="([^"]+)"/, 1]
      numbers = path.scan(/-?\d+(?:\.\d+)?/).map(&:to_f)
      start = numbers.shift(2)
      first_line = numbers.shift(2)
      expect(start[0] == first_line[0] || start[1] == first_line[1]).to be(true)
      final = route.points.last
      expect(path.scan(/-?\d+(?:\.\d+)?/).last(2).map(&:to_f)).to eq(final.map(&:to_f))
      expect(path).not_to match(/Q -?\d+(?:\.\d+)? -?\d+(?:\.\d+)? (-?\d+(?:\.\d+)?) (-?\d+(?:\.\d+)?) L \1 \2/)
      penultimate = route.points[-2]
      expect(final[0] == penultimate[0] || final[1] == penultimate[1]).to be(true)
    end
    exterior = scene.routes.select { |route| route.points.size > 4 }
    vertical_lanes = exterior.map { |route| route.points[1][0] }
    expect(vertical_lanes.uniq).to eq(vertical_lanes)
  end

  it 'uses generated accessibility text unless a custom description replaces it' do
    svg = representative.to_svg(id: 'uml-desc')
    expect(svg).to include('Interface Payable', 'CardPayment inherits Payment', 'CardPayment realizes Payable')
    custom = build(description: 'Exact custom description') do
      class_type :a, 'A'
      class_type :b, 'B'
      relation :a, :b, kind: :dependency
    end
    expect(custom.to_svg(id: 'uml-custom')).to include('<desc id="uml-custom-desc">Exact custom description</desc>')
  end
end
