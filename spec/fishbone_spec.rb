# frozen_string_literal: true
require 'spec_helper'
require 'json'
require 'cgi'
require 'slim_graph_r/document'

RSpec.describe 'bounded fishbone diagrams' do
  def fishbone_graph(style: :editorial, theme: :light, description: nil, lower: 1)
    SlimGraphR.diagram(:fishbone, title: 'Checkout latency investigation · 調査', style: style, theme: theme,
                      description: description) do
      effect 'Checkout p99 latency above 2 s'
      category(:data, 'Data', side: :above) { factor 'Missing index'; factor 'Replica lag' }
      category(:deployment, 'Deployment', side: :below) { factor 'Cold workers' }
      category(:observability, 'Observability', side: :above) { factor 'No query breakdown' }
      category(:network, 'Network', side: :below) { factor 'TLS negotiation' } if lower >= 2
      category(:runtime, 'Runtime', side: :below) { factor 'GC pauses' } if lower >= 3
    end
  end

  it 'uses dedicated immutable records and preserves author order' do
    graph = fishbone_graph
    expect(graph.fishbone_effect.to_h).to eq(label: 'Checkout p99 latency above 2 s')
    expect(graph.fishbone_categories.map(&:id)).to eq(%w[data deployment observability])
    expect(graph.fishbone_categories.first.factors).to eq(['Missing index', 'Replica lag'])
    expect(graph.fishbone_categories).to all(be_frozen)
    expect(graph.fishbone_categories.map(&:factors)).to all(be_frozen)
    expect([graph.fishbone_effect, graph.fishbone_categories]).to all(be_frozen)
  end

  it 'keeps standalone Ruby and strict JSON byte-identical with a fixed ID' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = TOPLEVEL_BINDING.eval(File.read(File.join(root, 'fishbone.rb'), encoding: 'UTF-8'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'fishbone.json'), encoding: 'UTF-8'))
    expect(json.to_svg(id: 'fishbone-contract')).to eq(ruby.to_svg(id: 'fishbone-contract'))
  end

  it 'requires one effect, two to five categories, both sides, one to three factors, and side budgets' do
    expect { SlimGraphR.diagram(:fishbone) {} }.to raise_error(SlimGraphR::Error, /exactly one effect/i)
    expect do
      SlimGraphR.diagram(:fishbone) do
        effect 'Observed'; category(:a, 'A', side: :above) { factor 'One' }; category(:b, 'B', side: :above) { factor 'Two' }
      end
    end.to raise_error(SlimGraphR::Error, /at least one category on each side/i)
    expect do
      SlimGraphR.diagram(:fishbone) do
        effect 'Observed'; category(:a, 'A', side: :above) {}; category(:b, 'B', side: :below) { factor 'Two' }
      end
    end.to raise_error(SlimGraphR::Error, /one to three factors/i)
    expect do
      SlimGraphR.diagram(:fishbone) do
        effect 'Observed'; category(:a, 'A', side: :above) { 4.times { |i| factor "F#{i}" } }; category(:b, 'B', side: :below) { factor 'Two' }
      end
    end.to raise_error(SlimGraphR::Error, /one to three factors/i)
    expect do
      SlimGraphR.diagram(:fishbone) do
        effect 'Observed'; 4.times { |i| category("a#{i}", "A#{i}", side: :above) { factor 'F' } }
        category(:b, 'B', side: :below) { factor 'F' }
      end
    end.to raise_error(SlimGraphR::Error, /at most three categories per side/i)
  end

  it 'keeps category scopes atomic when a block fails' do
    graph = nil
    expect do
      graph = SlimGraphR.diagram(:fishbone) do
        effect 'Observed'
        category(:bad, 'Bad', side: :above) { factor 'kept?'; raise 'stop' }
      end
    end.to raise_error(RuntimeError, 'stop')
    expect(graph).to be_nil
  end

  it 'renders exact sixty-degree bones, thirty-two-pixel ticks, clear arrow landing, and text bounds' do
    scene = fishbone_graph.layout
    expect(scene.bones).to all(satisfy { |bone| ((bone.attach_y - bone.far_y).abs.fdiv((bone.attach_x - bone.far_x).abs) - Math.sqrt(3)).abs < 0.02 })
    expect(scene.ticks).to all(satisfy { |tick| (tick.start_x - tick.end_x).abs == 32 && tick.start_y == tick.end_y })
    expect(scene.spine_end_x).to eq(scene.effect_box.rect[0])
    effect_rect = scene.effect_box.rect
    expect(scene.effect_text_bounds).to all(satisfy do |rect|
      rect[0] >= effect_rect[0] && rect[1] >= effect_rect[1] && rect[2] <= effect_rect[2] && rect[3] <= effect_rect[3]
    end)
    expect(scene.text_bounds).to all(satisfy { |rect| rect[0] >= 0 && rect[1] >= 0 && rect[2] <= scene.width && rect[3] <= scene.height })
    svg = fishbone_graph.to_svg(id: 'fishbone-geometry')
    expect(svg.scan('data-sgr-fishbone-bone=').size).to eq(3)
    expect(svg.scan('data-sgr-fishbone-tick=').size).to eq(4)
    expect(svg).to include('marker-end="url(#fishbone-geometry-arrow)"', 'data-sgr-effect="true"')
    expect(svg).to include('x="1100.0" y="311.5" class="sgr-fishbone-effect" text-anchor="middle"')
  end

  it 'widens the head and viewBox together for a third lower category' do
    ordinary = fishbone_graph(lower: 2).layout
    expanded = fishbone_graph(lower: 3).layout
    expect(expanded.width - ordinary.width).to eq(160)
    expect(expanded.head_x - ordinary.head_x).to eq(160)
    expect(expanded.bones.select { |bone| bone.record.side == :below }.last.far_x).to be >= 40
  end

  it 'renders all styles and light/dark themes above the physical text floor' do
    SlimGraphR::Style::PROFILES.keys.product(%i[light dark]).each do |style, theme|
      svg = fishbone_graph(style: style, theme: theme).to_svg(id: "fishbone-#{style}-#{theme}")
      expect(svg).to include(%(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}"), 'data-sgr-fishbone="true"')
      scale = svg[/data-sgr-display-scale="([\d.]+)"/, 1].to_f
      expect(scale * SlimGraphR::Layout::Fishbone::FACTOR_TEXT_SIZE).to be >= 12
    end
  end

  it 'states the evidentiary limit without inferring causation and honors exact replacement' do
    generated = CGI.unescapeHTML(fishbone_graph.to_svg(id: 'fishbone-description')[/<desc[^>]*>(.*?)<\/desc>/, 1])
    expect(generated).to include('Checkout p99 latency above 2 s', 'Data: Missing index, Replica lag')
    expect(generated).to include('investigated or associated leads', 'do not prove causation')
    expect(generated).not_to match(/root cause|confirmed|probability|blame/i)
    expect(fishbone_graph(description: 'Exact investigation summary.').to_svg(id: 'custom')).to include('<desc id="custom-desc">Exact investigation summary.</desc>')
  end

  it 'strictly rejects causal, focal, inferred, malformed, null, and cross-type JSON fields' do
    base = JSON.parse(File.read(File.expand_path('../examples/standalone/fishbone.json', __dir__), encoding: 'UTF-8'))
    mutations = [
      ->(d) { d['root_cause'] = 'data' }, ->(d) { d['confirmed'] = true }, ->(d) { d['confidence'] = 0.8 },
      ->(d) { d['blame'] = 'team' }, ->(d) { d['probability'] = 0.4 }, ->(d) { d['causal_strength'] = 'high' },
      ->(d) { d['focal'] = 'data' }, ->(d) { d['categories'][0]['focal'] = true }, ->(d) { d['categories'][0]['side'] = nil },
      ->(d) { d['effect'] = 'plain text' }, ->(d) { d['nodes'] = [] }, ->(d) { d['categories'][0]['factors'][0] = nil }
    ]
    mutations.each do |mutation|
      data = Marshal.load(Marshal.dump(base)); mutation.call(data)
      expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error)
    end
  end

  it 'fails actionable measured density rather than clipping or repairing content' do
    expect do
      SlimGraphR.diagram(:fishbone) do
        effect 'Observed effect'
        category(:a, 'A', side: :above) { factor 'A factor label that is intentionally much too long to fit the fixed safe tick corridor' }
        category(:b, 'B', side: :below) { factor 'Short' }
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /shorten|split|widen/i)
  end
end
