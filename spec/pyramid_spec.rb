# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'bounded pyramid and funnel diagrams' do
  it 'builds hierarchy and measured models with honest plateau and zero-tail quantities' do
    hierarchy = SlimGraphR.diagram(:pyramid) do
      level :base
      level :middle
      level :upper, focal: true
      level :apex
    end
    measured = SlimGraphR.diagram(:pyramid, orientation: :funnel, mode: :measured, unit: 'accounts') do
      level :all, from: 100, to: 100
      level :active, from: 100, to: 1, focal: true
      level :won, from: 1, to: 0
      level :tail, from: 0, to: 0
    end
    expect([hierarchy.orientation, hierarchy.mode, hierarchy.unit]).to eq([:pyramid, :hierarchy, nil])
    expect(measured.levels.map { |x| [x.from, x.to] }).to eq([[100, 100], [100, 1], [1, 0], [0, 0]])
    expect(measured.levels).to all(be_frozen)
  end

  it 'keeps strict JSON defaults and Ruby parity' do
    json = { type: 'pyramid', levels: %w[a b c d].map { |id| { id: id } } }
    parsed = SlimGraphR::Document.from_json(JSON.generate(json))
    ruby = SlimGraphR.diagram(:pyramid) { %i[a b c d].each { |id| level id } }
    expect(parsed.to_svg(id: 'pyramid-parity')).to eq(ruby.to_svg(id: 'pyramid-parity'))
    expect { SlimGraphR::Document.from_json(JSON.generate(json.merge(mode: nil))) }.to raise_error(SlimGraphR::Error)
    expect { SlimGraphR::Document.from_json(JSON.generate(json.merge(direction: 'down'))) }.to raise_error(SlimGraphR::Error, /direction/)
  end

  it 'keeps the executable standalone Ruby and JSON example equivalent' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = eval(File.read(File.join(root, 'pyramid.rb'), encoding: 'UTF-8'), binding, File.join(root, 'pyramid.rb'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'pyramid.json'), encoding: 'UTF-8'))
    expect(json.to_svg(id: 'pyramid-example')).to eq(ruby.to_svg(id: 'pyramid-example'))
  end

  it 'preserves exact proportional boundary widths without a readability floor' do
    graph = SlimGraphR.diagram(:pyramid, orientation: :funnel, mode: :measured, unit: 'leads') do
      level :reach, from: 1_000_000, to: 1_000_000
      level :active, from: 1_000_000, to: 10, focal: true
      level :won, from: 10, to: 1
      level :zero, from: 1, to: 0
    end
    scene = graph.layout
    expected = [[480.0, 480.0], [480.0, 0.0048], [0.0048, 0.00048], [0.00048, 0.0]]
    scene.pyramid_bands.zip(expected).each do |band, widths|
      expect(band[:from_width]).to be_within(1e-12).of(widths[0])
      expect(band[:to_width]).to be_within(1e-12).of(widths[1])
    end
    expect(scene.pyramid_bands.drop(1)).to all(satisfy { |band| band[:outside] })
    scene.pyramid_bands.select { |band| band[:outside] }.each do |band|
      expected_edge = 40.0 + 240.0 + (band[:top_width] + band[:bottom_width]) / 4.0
      expect(band[:anchor_x]).to be_within(1e-12).of(expected_edge)
      expect(band[:anchor_x]).to be > band[:points][0][0]
      expect(band[:anchor_x]).to be < 40.0 + 480.0
    end
    svg = graph.to_svg(id: 'sharp-drop')
    expect(svg).to include('data-sgr-pyramid-label-placement="outside"', '1 → 0 leads')
    expect(svg.scan('data-sgr-pyramid-label-mask').size).to be >= 3
    leader = scene.pyramid_bands.find { |band| band[:level].id == 'active' }
    expect(svg).to include(%(x1="#{leader[:anchor_x]}" y1="#{leader[:center_y]}"))
  end

  it 'renders declaration order correctly in pyramid and funnel orientations' do
    pyramid = SlimGraphR.diagram(:pyramid) do
      level :base
      level :middle
      level :upper
      level :apex, focal: true
    end.layout
    expect(pyramid.pyramid_bands.first[:y]).to be > pyramid.pyramid_bands.last[:y]
    funnel = SlimGraphR.diagram(:pyramid, orientation: :funnel, mode: :measured, unit: 'x') do
      level :wide, from: 8, to: 6
      level :next, from: 6, to: 4
      level :focus, from: 4, to: 2, focal: true
      level :end, from: 2, to: 0
    end.layout
    expect(funnel.pyramid_bands.first[:y]).to be < funnel.pyramid_bands.last[:y]
  end

  it 'rejects invalid modes, hierarchy quantities, broken or increasing chains, and base focus' do
    expect { SlimGraphR.diagram(:pyramid, orientation: :funnel) { 4.times { |i| level i } } }.to raise_error(SlimGraphR::Error, /Hierarchy.*pyramid/)
    expect { SlimGraphR.diagram(:pyramid, unit: 'things') { 4.times { |i| level i } } }.to raise_error(SlimGraphR::Error, /Hierarchy.*unit/)
    expect { SlimGraphR.diagram(:pyramid) { level(:base, focal: true); 3.times { |i| level i } } }.to raise_error(SlimGraphR::Error, /base cannot be focal/)
    expect { SlimGraphR.diagram(:pyramid) { 4.times { |i| level i, from: 4, to: 3 } } }.to raise_error(SlimGraphR::Error, /Hierarchy.*from or to/)
    broken = -> { SlimGraphR.diagram(:pyramid, mode: :measured, unit: 'x') { level(:a, from: 4, to: 3); level(:b, from: 2, to: 1); level(:c, from: 1, to: 0); level(:d, from: 0, to: 0) } }
    expect(&broken).to raise_error(SlimGraphR::Error, /chain is broken/)
    expect { SlimGraphR.diagram(:pyramid, mode: :measured, unit: 'x') { level(:a, from: 4, to: 5); 3.times { |i| level i, from: 5, to: 5 } } }.to raise_error(SlimGraphR::Error, /less than or equal/)
  end

  it 'rejects nonfinite, negative, and unrepresentable positive scales' do
    [Float::NAN, Float::INFINITY, -1].each do |bad|
      expect do
        SlimGraphR.diagram(:pyramid, mode: :measured, unit: 'x') do
          level :a, from: 10, to: bad
          level :b, from: bad, to: 0
          level :c, from: 0, to: 0
          level :d, from: 0, to: 0
        end
      end.to raise_error(SlimGraphR::Error, /finite nonnegative/)
    end
    expect do
      SlimGraphR.diagram(:pyramid, mode: :measured, unit: 'x') do
        level :a, from: Float::MAX, to: Float::MIN
        level :b, from: Float::MIN, to: 0
        level :c, from: 0, to: 0
        level :d, from: 0, to: 0
      end
    end.to raise_error(SlimGraphR::Error, /cannot preserve.*positive boundary/)
    expect do
      SlimGraphR.diagram(:pyramid, mode: :measured, unit: 'x') do
        level :a, from: 1.0, to: 1e-300
        level :b, from: 1e-300, to: 0
        level :c, from: 0, to: 0
        level :d, from: 0, to: 0
      end
    end.to raise_error(SlimGraphR::Error, /cannot preserve.*positive boundary/)
  end

  it 'accepts very large finite plateaus in Ruby and JSON without intermediate overflow' do
    ruby = SlimGraphR.diagram(:pyramid, mode: :measured, unit: 'events') do
      4.times { |i| level "p#{i}", from: 1e308, to: 1e308, focal: i == 2 }
    end
    data = { type: 'pyramid', mode: 'measured', unit: 'events', levels: 4.times.map do |i|
      { id: "p#{i}", from: 1e308, to: 1e308, focal: i == 2 }
    end }
    json = SlimGraphR::Document.from_json(JSON.generate(data))
    expect(json.to_svg(id: 'huge')).to eq(ruby.to_svg(id: 'huge'))
    expect(ruby.layout.pyramid_bands.flat_map { |band| [band[:from_width], band[:to_width]] }.uniq).to eq([480.0])
  end

  it 'enforces text, count, focus, unknown, null, and cross-type limits' do
    expect { SlimGraphR.diagram(:pyramid) { 3.times { |i| level i } } }.to raise_error(SlimGraphR::Error, /four to six/)
    expect { SlimGraphR.diagram(:pyramid) { 4.times { |i| level i, 'x' * 29 } } }.to raise_error(SlimGraphR::Error, /28/)
    base = { type: 'pyramid', levels: %w[a b c d].map { |id| { id: id } } }
    [base.merge(levels: base[:levels].map(&:dup).tap { |x| x[0][:detail] = nil }),
     base.merge(levels: base[:levels].map(&:dup).tap { |x| x[0][:wat] = 1 }),
     base.merge(tiers: [])].each do |bad|
      expect { SlimGraphR::Document.from_json(JSON.generate(bad)) }.to raise_error(SlimGraphR::Error)
    end
    expect do
      SlimGraphR::Document.from_json(JSON.generate(type: 'architecture', nodes: [{ id: 'a' }], levels: []))
    end.to raise_error(SlimGraphR::Error, /Only pyramid and medallion/)
  end

  it 'generates a clear ordinal description and supports Unicode in all styles and themes' do
    graph = SlimGraphR.diagram(:pyramid, title: '证据 Échelle') do
      level :base, 'Contexte'
      level :middle, 'Études'
      level :upper, 'Synthèse', focal: true
      level :apex, 'Décision'
    end
    expect(graph.to_svg).to include('Ordinal hierarchy; taper shows rank and does not encode quantity.', 'Synthèse')
    %i[editorial ruby blueprint mono].product(%i[light dark auto]).each do |style, theme|
      expect(graph.with(style: style, theme: theme).to_svg).to include(%(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}"))
    end
  end
end
