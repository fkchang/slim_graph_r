require 'spec_helper'
RSpec.describe SlimGraphR do
  def build(type = :architecture, **options, &block) = described_class.diagram(type, **options, &block)

  it 'authors a chain without coordinates or repeated labels' do
    graph = build do
      node :request
      decision :review, emphasis: true
      store :archive
      flow :request, :review, :archive
    end
    expect(graph.nodes.map(&:label)).to eq(%w[Request Review Archive])
    expect(graph.edges.map { |e| [e.from, e.to] }).to eq([%w[request review], %w[review archive]])
    expect(graph.nodes.last.kind).to eq(:store)
  end

  it 'accepts natural edge and message annotations' do
    graph = build(:sequence) do
      participant :client
      participant :api, 'API'
      message :client, :api, 'Fetch'
      message :api, :client, label: 'Ready', dashed: true
    end
    expect(graph.edges.map(&:label)).to eq(%w[Fetch Ready])
    expect(graph.layout.routes.size).to eq(2)
  end

  it 'fails loudly for unknown references, duplicate IDs and excess emphasis' do
    expect { build { node :a; edge :a, :missing } }.to raise_error(SlimGraphR::Error, /Unknown node/)
    expect { build { node :a; node :a } }.to raise_error(SlimGraphR::Error, /unique/)
    expect { build { %i[a b c].each { |id| node id, emphasis: true } } }.to raise_error(SlimGraphR::Error, /two emphasized/)
    expect { build(:pie) {} }.to raise_error(SlimGraphR::Error, /Mermaid/)
    expect { build { 33.times { |i| node i } } }.to raise_error(SlimGraphR::Error, /Limit/)
  end

  it 'escapes all user text and rejects invalid XML characters and SVG IDs' do
    graph = build(title: '<script>alert(1)</script>') { node :a, '<img src=x onerror=alert(1)>', detail: 'A & B' }
    svg = graph.to_svg
    doc = REXML::Document.new(svg)
    expect(REXML::XPath.match(doc, '//*[local-name()="script"]')).to be_empty
    expect(svg).to include('&lt;script&gt;', 'A &amp; B')
    expect { graph.to_svg(id: 'x" onload="x') }.to raise_error(SlimGraphR::Error, /SVG ID/)
    expect { build { node :a, "\xff".force_encoding('UTF-8') } }.to raise_error(SlimGraphR::Error, /UTF-8/)
    expect { build { node :a, "bad\x01" } }.to raise_error(SlimGraphR::Error, /XML/)
  end

  it 'provides descriptive accessibility metadata and collision-free IDs' do
    graph = build { node :a; node :b; edge :a, :b, 'Next' }
    first, second = graph.to_svg, graph.to_svg
    expect(first).to include('role="img"', 'A to B: Next')
    first_ids = first.scan(/\bid="([^"]+)"/).flatten
    expect(first_ids & second.scan(/\bid="([^"]+)"/).flatten).to be_empty
    expect(graph.to_svg(id: 'example')).to eq(graph.to_svg(id: 'example'))
  end

  it 'includes group membership in accessible descriptions and honors custom descriptions' do
    grouped = build do
      group(:backend, 'Backend') { node :api, 'API'; store :database }
      edge :api, :database
    end
    expect(grouped.to_svg).to include('Backend contains API, Database.')
    custom = build(description: 'A custom summary') { group(:backend) { node :api } }
    xml = REXML::Document.new(custom.to_svg)
    expect(REXML::XPath.first(xml, '//*[local-name()="desc"]').text).to eq('A custom summary')
  end

  it 'uses self-contained themes without a rendering network dependency' do
    %i[light dark auto].each do |theme|
      svg = build(theme: theme) { node :a }.to_svg
      expect(svg).to include("data-sgr-theme=\"#{theme}\"")
      expect(svg).not_to match(/<script|@import|<link|https:\/\/fonts/)
    end
  end

  it 'uses its display scale as a minimum physical text floor while allowing responsive growth' do
    expect(SlimGraphR::SVG::MINIMUM_TEXT_SIZE.keys).to match_array(SlimGraphR::Diagram::TYPES)
    expect(SlimGraphR::SVG::READABLE_BODY_SIZE).to eq(14)
    expect(SlimGraphR::SVG::READABLE_METADATA_SIZE).to eq(12)
    graph = build { node :draft; node :published; flow :draft, :published }
    root = graph.to_svg(id: 'readable')[/<svg[^>]+>/]
    authored_width = root[/viewBox="0 0 ([\d.]+)/, 1].to_f
    display_width = root[/\bwidth="(\d+)"/, 1].to_f
    scale = display_width / authored_width
    metadata_size = SlimGraphR::SVG::MINIMUM_TEXT_SIZE.fetch(graph.type)
    expect(scale * SlimGraphR::SVG::BODY_TEXT_SIZE).to eq(14)
    expect(scale * metadata_size).to eq(12)
    expect(display_width).to eq(authored_width)
    expect(root).to include(%(data-sgr-display-scale="1"), %(min-width:#{display_width.to_i}px),
                            'width:100%', 'height:auto')
    expect(root).not_to include('max-width:')
  end

  it 'wraps long words and Unicode without losing content' do
    text = '非常に長い名前と説明 a_very_long_identifier_without_spaces_0123456789 café'
    lines = SlimGraphR::Text.wrap(text, 120)
    expect(lines.all? { |line| SlimGraphR::Text.width(line) <= 120 }).to be(true)
    expect(lines.join.delete(' ')).to eq(text.delete(' '))
    expect(SlimGraphR::Text.width("e\u0301")).to eq(SlimGraphR::Text.width('e'))
  end
end
