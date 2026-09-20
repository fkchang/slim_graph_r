# frozen_string_literal: true
require 'spec_helper'
require 'json'
require 'slim_graph_r/document'

RSpec.describe 'bounded Wardley maps' do
  def build(style: :editorial, theme: :light)
    SlimGraphR.diagram(:wardley, title: 'Assistant value chain · 価値連鎖', style: style, theme: theme) do
      component :assistant, 'AI assistant', evolution: :genesis, visibility: 0.82
      component :orchestration, 'Agent orchestration', evolution: :custom_built, visibility: 0.58
      component :model_api, 'Model API', evolution: :product, visibility: 0.36, evolving_to: :commodity
      component :compute, 'Compute', evolution: :commodity, visibility: 0.14
      depends_on :assistant, :orchestration
      depends_on :orchestration, :model_api
      depends_on :model_api, :compute
    end
  end

  it 'keeps immutable dedicated records and exact authored visibility mapping' do
    diagram = build
    expect(diagram.wardley_components.map(&:to_h)).to eq([
      { id: 'assistant', label: 'AI assistant', evolution: :genesis, visibility: 0.82, evolving_to: nil },
      { id: 'orchestration', label: 'Agent orchestration', evolution: :custom_built, visibility: 0.58, evolving_to: nil },
      { id: 'model_api', label: 'Model API', evolution: :product, visibility: 0.36, evolving_to: :commodity },
      { id: 'compute', label: 'Compute', evolution: :commodity, visibility: 0.14, evolving_to: nil }
    ])
    expect(diagram.wardley_components).to all(be_frozen)
    expect(diagram.wardley_dependencies).to be_frozen
    expect(diagram.wardley_dependencies).to all(be_frozen)
    point = diagram.layout.points.first
    expect(point.cx).to eq(SlimGraphR::Layout::Wardley::PLOT_LEFT + SlimGraphR::Layout::Wardley::BAND_WIDTH / 2.0)
    expect(point.cy).to be_within(1e-12).of(SlimGraphR::Layout::Wardley::PLOT_TOP + 0.18 * SlimGraphR::Layout::Wardley::PLOT_HEIGHT)
  end

  it 'constructs byte-identical Ruby and strict JSON diagrams with a fixed ID' do
    from_json = SlimGraphR::Document.from_json(File.read(File.expand_path('../examples/standalone/wardley.json', __dir__), encoding: 'UTF-8'))
    ruby = TOPLEVEL_BINDING.eval(File.read(File.expand_path('../examples/standalone/wardley.rb', __dir__), encoding: 'UTF-8'))
    expect(from_json.wardley_components.map(&:to_h)).to eq(ruby.wardley_components.map(&:to_h))
    expect(from_json.to_svg(id: 'wardley-contract')).to eq(ruby.to_svg(id: 'wardley-contract'))
  end

  it 'enforces qualitative enums, finite visibility, adjacency, budgets, references, and incidence' do
    expect { SlimGraphR.diagram(:wardley, direction: :down) }.to raise_error(SlimGraphR::Error, /do not accept direction/)
    expect { SlimGraphR.diagram(:wardley) { component :a, 'A', evolution: :score, visibility: 0.5 } }.to raise_error(SlimGraphR::Error, /evolution/)
    [Float::NAN, Float::INFINITY, -0.01, 1.01, '0.5'].each do |visibility|
      expect { SlimGraphR.diagram(:wardley) { component :a, 'A', evolution: :genesis, visibility: visibility } }.to raise_error(SlimGraphR::Error, /visibility/)
    end
    expect do
      SlimGraphR.diagram(:wardley) do
        component :a, 'A', evolution: :genesis, visibility: 0.8, evolving_to: :product
        component :b, 'B', evolution: :product, visibility: 0.2
        depends_on :a, :b
      end
    end.to raise_error(SlimGraphR::Error, /adjacent/)
    expect do
      SlimGraphR.diagram(:wardley) do
        component :a, 'A', evolution: :genesis, visibility: 0.8
        component :b, 'B', evolution: :product, visibility: 0.2
        component :c, 'C', evolution: :commodity, visibility: 0.1
        depends_on :a, :b
      end
    end.to raise_error(SlimGraphR::Error, /incident.*c/i)
    expect do
      SlimGraphR.diagram(:wardley) do
        component :a, 'A', evolution: :genesis, visibility: 0.8
        component :b, 'B', evolution: :product, visibility: 0.2
        depends_on :a, :missing
      end
    end.to raise_error(SlimGraphR::Error, /Unknown Wardley component: missing/)
  end


  it 'rejects duplicate dependencies, a third movement, and crossing dependency lines' do
    expect do
      SlimGraphR.diagram(:wardley) do
        component :a, 'A', evolution: :genesis, visibility: 0.8
        component :b, 'B', evolution: :product, visibility: 0.2
        depends_on :a, :b
        depends_on :a, :b
      end
    end.to raise_error(SlimGraphR::Error, /unique/)
    expect do
      SlimGraphR.diagram(:wardley) do
        component :a, 'A', evolution: :genesis, visibility: 0.8, evolving_to: :custom_built
        component :b, 'B', evolution: :custom_built, visibility: 0.6, evolving_to: :product
        component :c, 'C', evolution: :product, visibility: 0.4, evolving_to: :commodity
        component :d, 'D', evolution: :commodity, visibility: 0.2
        depends_on :a, :b; depends_on :b, :c; depends_on :c, :d
      end
    end.to raise_error(SlimGraphR::Error, /at most two/)
    crossing = SlimGraphR.diagram(:wardley) do
      component :a, 'A', evolution: :genesis, visibility: 0.8
      component :b, 'B', evolution: :custom_built, visibility: 0.2
      component :c, 'C', evolution: :product, visibility: 0.8
      component :d, 'D', evolution: :commodity, visibility: 0.2
      depends_on :a, :d
      depends_on :b, :c
    end
    svg = crossing.to_svg(id: 'wardley-crossing')
    expect(svg.scan(/data-sgr-hops="(\d+)"/).flatten.map(&:to_i).sum).to be >= 1
  end

  it 'renders four qualitative bands, straight links, one movement, caption, and readable type floor' do
    SlimGraphR::Style::PROFILES.keys.product(%i[light dark]).each do |style, theme|
      svg = build(style: style, theme: theme).to_svg(id: "wardley-#{style}-#{theme}")
      expect(svg).to include('data-sgr-wardley="true"', 'data-sgr-wardley-caption="true"')
      expect(svg).to include('Band and visibility positions are qualitative author judgments, not calculated scores.')
      %w[GENESIS CUSTOM-BUILT PRODUCT COMMODITY].each { |label| expect(svg).to include(">#{label}<") }
      expect(svg.scan('data-sgr-wardley-component=').size).to eq(4)
      expect(svg.scan('data-sgr-wardley-dependency=').size).to eq(3)
      expect(svg.scan('data-sgr-wardley-movement=').size).to eq(1)
      expect(svg).to include('stroke-dasharray="5 4"', 'marker-end="url(#wardley-')
      expect(svg).not_to include('data-sgr-wardley-tick', 'score=', 'writing-mode')
      expect(svg).to include('data-sgr-display-scale="1"', 'font-size:12px', 'width="1120"')
    end
  end

  it 'generates declared-position descriptions and honors a supplied description' do
    desc = CGI.unescapeHTML(build.to_svg(id: 'wardley-description')[/<desc[^>]*>(.*?)<\/desc>/, 1])
    expect(desc).to include('AI assistant is authored in Genesis at visibility 0.82.')
    expect(desc).to include('Model API is authored in Product at visibility 0.36 and evolving to Commodity.')
    expect(desc).to include('AI assistant depends on Agent orchestration.')
    expect(desc).to include('Band and visibility positions are qualitative author judgments, not calculated scores.')
    custom = SlimGraphR.diagram(:wardley, description: 'Literal accessible map description.') do
      component :a, 'A', evolution: :genesis, visibility: 0.8
      component :b, 'B', evolution: :custom_built, visibility: 0.2
      depends_on :a, :b
    end
    expect(custom.to_svg(id: 'custom-desc')).to include('>Literal accessible map description.</desc>')
  end

  it 'strictly rejects nulls, unknown keys, wrong types, and cross-type or deferred fields' do
    base = JSON.parse(File.read(File.expand_path('../examples/standalone/wardley.json', __dir__), encoding: 'UTF-8'))
    mutations = [
      ->(d) { d['components'][0]['evolving_to'] = nil }, ->(d) { d['components'][0]['visibility'] = '0.8' },
      ->(d) { d['components'][0]['x'] = 0.1 }, ->(d) { d['components'][0]['focal'] = true },
      ->(d) { d['dependencies'][0]['label'] = 'runtime' }, ->(d) { d['nodes'] = [] },
      ->(d) { d['direction'] = 'right' }, ->(d) { d['score'] = 7 }
    ]
    mutations.each do |mutation|
      data = Marshal.load(Marshal.dump(base)); mutation.call(data)
      expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error)
    end
  end

  it 'raises actionable LayoutError without moving authored dots on any protected interference' do
    diagram = SlimGraphR.diagram(:wardley) do
      component :a, 'A very long label that overlaps protected map geometry and cannot be faithfully placed', evolution: :genesis, visibility: 0.99
      component :b, 'B', evolution: :custom_built, visibility: 0.98
      depends_on :a, :b
    end
    expect { diagram.to_svg }.to raise_error(SlimGraphR::LayoutError, /shorten|spread|split/i)
    expect(diagram.wardley_components.first.visibility).to eq(0.99)
  end
end
