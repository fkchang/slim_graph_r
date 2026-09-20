require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe SlimGraphR::Style do
  def luminance(hex)
    values = hex.delete_prefix('#').scan(/../).map { |v| v.to_i(16) / 255.0 }
    values.map! { |v| v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4 }
    values.zip([0.2126, 0.7152, 0.0722]).sum { |v, weight| v * weight }
  end

  it 'keeps all built-in text palettes legible on their rendered surfaces' do
    described_class.names.each do |name|
      profile = described_class.fetch(name)
      [profile.light, profile.dark].each do |palette|
        %i[paper secondary tint].each do |surface|
          %i[ink muted accent].each do |role|
            high, low = [luminance(palette[role]), luminance(palette[surface])].sort.reverse
            expect((high + 0.05) / (low + 0.05)).to be >= 4.5, "#{name} #{role} on #{surface}"
          end
        end
      end
    end
  end

  it 'keeps the old default and supplies independently scoped styles, including minimal' do
    graph = SlimGraphR.diagram { node :a }
    expect(graph.style).to eq(:editorial)
    described_class.names.each do |name|
      changed = graph.with(style: name, theme: :dark)
      expect(changed.to_svg).to include("data-sgr-style=\"#{name}\"", described_class.fetch(name).dark[:paper])
      expect(changed.nodes).to equal(graph.nodes)
      expect(changed).to be_frozen
    end
    expect(graph.theme).to eq(:light)
    expect { graph.with(style: :missing) }.to raise_error(SlimGraphR::Error, /Unknown style/)
    expect { graph.with(theme: :ruby) }.to raise_error(SlimGraphR::Error, /Theme/)
  end

  it 'keeps minimal distinct from editorial through Ruby and strict JSON documents' do
    ruby = SlimGraphR.diagram(:flowchart, style: :minimal, theme: :dark) do
      start :begin
      finish :finish, emphasis: true
      flow :begin, :finish
    end
    parsed = SlimGraphR::Document.from_json(<<~JSON)
      {"type":"flowchart","style":"minimal","theme":"dark","nodes":[{"id":"begin","kind":"start"},{"id":"finish","kind":"finish","emphasis":true}],"edges":[{"from":"begin","to":"finish"}]}
    JSON

    expect(parsed.style).to eq(:minimal)
    expect(parsed.to_svg(id: 'minimal-json')).to include('data-sgr-style="minimal"', '#111827', 'stroke-width="2"')
    expect(ruby.to_svg(id: 'minimal-ruby')).to include('data-sgr-style="minimal"', '--sgr-node-radius:2', '--sgr-node-inset:16')
    expect(ruby.style_profile).not_to equal(SlimGraphR::Style.fetch(:editorial))
  end

  it 'uses an independent restrained crimson focal palette rather than the generic teal treatment' do
    minimal = described_class.fetch(:minimal)
    ruby = described_class.fetch(:ruby)

    expect(minimal.light.slice(:accent, :tint)).to eq(accent: '#9f1239', tint: '#fce7ef')
    expect(minimal.dark.slice(:accent, :tint)).to eq(accent: '#fda4af', tint: '#4c1d2f')
    expect(minimal.light).not_to eq(ruby.light)
    expect(minimal.dark).not_to eq(ruby.dark)
    expect(minimal.light.values + minimal.dark.values).not_to include('#0f766e', '#5eead4', '#e6fffa', '#134e4a')
  end

  it 'covers the full standalone document with the resolved dark paper for short minimal diagrams' do
    diagrams = [
      SlimGraphR.diagram(:architecture, style: :minimal, theme: :dark) { node :reader; node :origin; flow :reader, :origin },
      SlimGraphR.diagram(:sequence, style: :minimal, theme: :dark) { participant :reader; participant :origin; message :reader, :origin, 'GET' },
      SlimGraphR.diagram(:timeline, style: :minimal, theme: :dark) { event '2026-01-01', 'Start'; event '2026-02-01', 'Ship' }
    ]

    diagrams.each do |diagram|
      expect(diagram.to_html).to include('<style>html,body{margin:0;min-height:100%;background:#111827}body{min-height:100vh}</style>')
    end
  end

  it 'measures a monospaced heading before wrapping instead of only painting new CSS' do
    text = 'iiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiii'
    sans = SlimGraphR::Text.wrap(text, 280, 30, font: :sans)
    mono = SlimGraphR::Text.wrap(text, 280, 30, font: :mono)
    expect(mono.first.length).to be < sans.first.length
    graph = SlimGraphR.diagram(:timeline, title: text, style: :blueprint) { event 'Today', text }
    expect(graph.to_svg).to include('ui-monospace')
    graph.layout.events.first[:lines].each do |line|
      expect(SlimGraphR::Text.width(line, 18, font: :mono)).to be <= 424
    end
  end
end
