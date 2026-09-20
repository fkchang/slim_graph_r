# frozen_string_literal: true
require 'spec_helper'
require 'json'
require 'rexml/document'
require 'slim_graph_r/document'

RSpec.describe 'bounded Venn diagrams' do
  def three_set(style: :editorial, theme: :light, description: nil)
    SlimGraphR.diagram(:venn, title: 'Product fit · 適合', style: style, theme: theme, description: description) do
      set :desirable, 'Desirable'
      set :feasible, 'Feasible'
      set :viable, 'Viable'
      intersection [:desirable, :feasible], 'Useful'
      intersection [:desirable, :viable], 'Wanted'
      intersection [:feasible, :viable], 'Sustainable'
      intersection [:desirable, :feasible, :viable], 'Product fit', focal: true
    end
  end

  def two_set
    SlimGraphR.diagram(:venn, title: 'Evidence · 証拠') do
      set :observed, 'Observed facts'
      set :explained, 'Explained causes'
      intersection [:observed, :explained], 'Supported account'
    end
  end

  it 'builds frozen dedicated records while preserving authored intersection member order' do
    graph = three_set
    expect(graph.venn_sets.map(&:to_h)).to eq([
      { id: 'desirable', label: 'Desirable', subtitle: nil }, { id: 'feasible', label: 'Feasible', subtitle: nil }, { id: 'viable', label: 'Viable', subtitle: nil }
    ])
    expect(graph.intersections.last.to_h).to eq(sets: %w[desirable feasible viable], label: 'Product fit', focal: true)
    expect(graph.venn_sets).to be_frozen
    expect(graph.intersections).to be_frozen
    expect(graph.intersections).to all(be_frozen)
    expect(graph.intersections).to all(satisfy { |item| item.sets.frozen? })
  end

  it 'keeps standalone Ruby and strict JSON byte-identical with a fixed ID' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = TOPLEVEL_BINDING.eval(File.read(File.join(root, 'venn.rb'), encoding: 'UTF-8'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'venn.json'), encoding: 'UTF-8'))
    expect(json.intersections.map(&:to_h)).to eq(ruby.intersections.map(&:to_h))
    expect(json.to_svg(id: 'venn-contract')).to eq(ruby.to_svg(id: 'venn-contract'))
  end

  it 'requires the complete exact topology for two and three sets' do
    expect(two_set.intersections.map(&:sets)).to eq([%w[observed explained]])
    expect do
      SlimGraphR.diagram(:venn) do
        set :a, 'A'; set :b, 'B'; set :c, 'C'
        intersection %i[a b], 'AB'; intersection %i[a c], 'AC'; intersection %i[a b c], 'ABC'
      end
    end.to raise_error(SlimGraphR::Error, /every pair and the triple|missing.*b.*c/i)
    expect do
      SlimGraphR.diagram(:venn) { set :a, 'A'; set :b, 'B'; intersection %i[a b], 'AB'; intersection %i[b a], 'again' }
    end.to raise_error(SlimGraphR::Error, /duplicate topology/i)
    expect { SlimGraphR.diagram(:venn) { set :a, 'A' } }.to raise_error(SlimGraphR::Error, /exactly two or three sets/i)
    expect do
      SlimGraphR.diagram(:venn) { set :a, 'A'; set :b, 'B'; set :c, 'C'; set :d, 'D' }
    end.to raise_error(SlimGraphR::Error, /exactly two or three sets/i)
  end

  it 'validates identities, members, focal values and graph-DSL exclusivity' do
    expect do
      SlimGraphR.diagram(:venn) { set :a, 'A'; set :a, 'Again'; intersection %i[a a], 'same' }
    end.to raise_error(SlimGraphR::Error, /IDs must be unique|distinct/i)
    expect do
      SlimGraphR.diagram(:venn) { set :a, 'A'; set :b, 'B'; intersection %i[a missing], 'unknown' }
    end.to raise_error(SlimGraphR::Error, /unknown set.*missing/i)
    expect do
      SlimGraphR.diagram(:venn) { set :a, 'A'; set :b, 'B'; intersection %i[a b], 'AB', focal: nil }
    end.to raise_error(SlimGraphR::Error, /true or false/i)
    expect do
      SlimGraphR.diagram(:venn) { set :a, 'A'; set :b, 'B'; intersection %i[a b], 'AB'; node :x }
    end.to raise_error(SlimGraphR::Error, /dedicated set and intersection records/i)
    expect { SlimGraphR.diagram(:architecture) { set :a, 'A' } }.to raise_error(SlimGraphR::Error, /only in a Venn diagram/i)
    expect { SlimGraphR.diagram(:venn) { set :a, 'A', subtitle: ' '; set :b, 'B'; intersection %i[a b], 'AB' } }
      .to raise_error(SlimGraphR::Error, /subtitle.*blank/i)
  end

  it 'renders authored set subtitles and carries them into the generated description' do
    graph = SlimGraphR.diagram(:venn) do
      set :a, 'A', subtitle: 'AUTHOR SUPPLIED'
      set :b, 'B'
      intersection %i[a b], 'AB'
    end
    svg = graph.to_svg(id: 'venn-subtitle')
    expect(svg).to include('data-sgr-venn-set-subtitle="a"', 'AUTHOR SUPPLIED', 'Sets: A: AUTHOR SUPPLIED, B.')
    expect(svg).to match(/\.sgr-venn-set-subtitle\{[^}]*font-size:12px/)
    expect(SlimGraphR::Layout::Venn::SUBTITLE_TEXT_SIZE).to eq(12)
  end

  it 'measures authored subtitles at their rendered metadata size' do
    boundary_subtitle = 'M' * 29
    expect(SlimGraphR::Text.width(boundary_subtitle, 9, font: :mono) + 8).to be <= 220
    expect(SlimGraphR::Text.width(boundary_subtitle, 12, font: :mono) + 8).to be > 220
    graph = SlimGraphR.diagram(:venn) do
      set :a, 'A', subtitle: boundary_subtitle
      set :b, 'B'
      intersection %i[a b], 'AB'
    end
    expect { graph.to_svg }.to raise_error(SlimGraphR::LayoutError, /set label.*cannot fit.*shorten.*set label|split.*diagram/i)
  end

  it 'renders exact fixed equal-circle templates, compound tints, external labels, and one clipped focal region' do
    two = two_set.to_svg(id: 'venn-two')
    three = three_set.to_svg(id: 'venn-three')
    expect(two.scan('data-sgr-venn-circle=').size).to eq(2)
    expect(two).to include('cx="360" cy="300" r="224"', 'cx="632" cy="300" r="224"')
    expect(three.scan('data-sgr-venn-circle=').size).to eq(3)
    expect(three).to include('cx="380" cy="260" r="192"', 'cx="612" cy="260" r="192"', 'cx="496" cy="460" r="192"')
    expect(three.scan('fill-opacity="0.055"').size).to eq(3)
    expect(three.scan('data-sgr-venn-set-label=').size).to eq(3)
    expect(three.scan('data-sgr-venn-region-label=').size).to eq(4)
    expect(three).to include('data-sgr-venn-focal-clip="true"', 'clip-path="url(#venn-three-venn-focal-clip)"')
  end

  it 'keeps every measured label rectangle clear of every circle stroke and other label rectangle' do
    [two_set.layout, three_set.layout].each do |scene|
      rects = scene.set_labels.map(&:rect) + scene.region_labels.map(&:rect)
      rects.combination(2) { |a, b| expect(SlimGraphR::Layout::Venn.overlap?(a, b)).to be(false) }
      scene.set_labels.each do |label|
        scene.circles.each { |circle| expect(SlimGraphR::Layout::Venn.rect_crosses_circle?(label.rect, circle)).to be(false) }
      end
      scene.region_labels.each do |label|
        scene.circles.each { |circle| expect(SlimGraphR::Layout::Venn.rect_crosses_circle?(label.rect, circle)).to be(false) }
      end
    end
  end

  it 'raises actionable layout errors without changing the fixed topology' do
    graph = SlimGraphR.diagram(:venn) do
      set :a, 'A'; set :b, 'B'
      intersection %i[a b], 'This authored overlap label is deliberately much too long for the fixed clear lens region'
    end
    expect { graph.to_svg }.to raise_error(SlimGraphR::LayoutError, /shorten.*overlap label|split.*diagram/i)
    expect(graph.venn_sets.map(&:id)).to eq(%w[a b])
  end

  it 'renders every style and light/dark theme at a physical twelve-pixel floor' do
    expect(SlimGraphR::SVG::MINIMUM_TEXT_SIZE.fetch(:venn)).to eq(12)
    SlimGraphR::Style::PROFILES.keys.product(%i[light dark]).each do |style, theme|
      svg = three_set(style: style, theme: theme).to_svg(id: "venn-#{style}-#{theme}")
      expect(svg).to include(%(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}"), 'data-sgr-venn="true"')
      scale = svg[/data-sgr-display-scale="([\d.]+)"/, 1].to_f
      expect(scale * SlimGraphR::Layout::Venn::REGION_TEXT_SIZE).to be >= 12
      expect(svg).to include('font-size:16px')
    end
  end

  it 'generates topology-only descriptions and honors exact author replacement' do
    authored = CGI.unescapeHTML(three_set.to_svg(id: 'venn-description')[/<desc[^>]*>(.*?)<\/desc>/, 1])
    expect(authored).to include('Desirable ∩ Feasible: Useful', 'Desirable ∩ Viable: Wanted', 'Feasible ∩ Viable: Sustainable')
    expect(authored).to include('Desirable ∩ Feasible ∩ Viable: Product fit; author-selected focal overlap')
    expect(authored).to include('Equal circles encode named topology only; area and population are not quantitative.')
    expect(three_set(description: 'Exact Venn summary.').to_svg(id: 'custom')).to include('<desc id="custom-desc">Exact Venn summary.</desc>')
  end

  it 'strictly rejects null, unknown, malformed, quantity, position, color and cross-type JSON fields' do
    base = JSON.parse(File.read(File.expand_path('../examples/standalone/venn.json', __dir__), encoding: 'UTF-8'))
    mutations = [
      ->(d) { d['sets'][0]['label'] = nil }, ->(d) { d['intersections'][0]['focal'] = nil },
      ->(d) { d['sets'][0]['count'] = 12 }, ->(d) { d['sets'][0]['radius'] = 90 },
      ->(d) { d['sets'][0]['color'] = '#fff' }, ->(d) { d['sets'][0]['position'] = [0, 0] },
      ->(d) { d['intersections'][0]['weight'] = 0.4 }, ->(d) { d['nodes'] = [] },
      ->(d) { d['sets'] = 'not an array' }, ->(d) { d['intersections'][0]['sets'] = ['desirable', nil] }
    ]
    mutations.each do |mutation|
      data = Marshal.load(Marshal.dump(base)); mutation.call(data)
      expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error)
    end
  end
end
