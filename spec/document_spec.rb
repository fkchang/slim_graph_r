require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe SlimGraphR::Document do
  let(:data) { { type: 'architecture', nodes: [{ id: 'a' }, { id: 'b' }], edges: [{ from: 'a', to: 'b' }] } }
  def load_json(data) = described_class.from_json(JSON.generate(data))

  it 'renders the packaged JSON and Ruby examples with identical meaning and geometry' do
    root = File.expand_path('../examples/standalone', __dir__)
    json = described_class.from_json(File.read(File.join(root, 'publishing.json')))
    ruby = eval(File.read(File.join(root, 'publishing.rb')), binding, File.join(root, 'publishing.rb'))
    expect(json.to_svg(id: 'parity')).to eq(ruby.to_svg(id: 'parity'))
  end

  it 'preserves grouping, labels, styles and edges' do
    data[:style] = 'ruby'
    data[:groups] = [{ id: 'backend', label: 'Backend' }]
    data[:nodes][1][:group] = 'backend'
    data[:nodes][0][:label] = '<script>alert(1)</script>'
    graph = load_json(data)
    expect(graph.style).to eq(:ruby)
    expect(graph.nodes.last.group).to eq('backend')
    expect(graph.to_svg).to include('&lt;script&gt;', 'Backend contains B.')
  end

  it 'rejects invalid shapes, booleans, unknown fields and references' do
    expect { load_json([]) }.to raise_error(SlimGraphR::Error, /object/)
    expect { load_json(data.merge(nodes: {})) }.to raise_error(SlimGraphR::Error, /array/)
    expect { load_json(data.merge(typo: true)) }.to raise_error(SlimGraphR::Error, /Unknown/)
    expect { load_json(data.merge(nodes: [{ id: 'a', emphasis: 'false' }])) }.to raise_error(SlimGraphR::Error, /true or false/)
    expect { load_json(data.merge(nodes: [{ id: 'a', kind: nil }])) }.to raise_error(SlimGraphR::Error, /string/)
    expect { load_json(data.merge(nodes: [{ id: 'a', group: 'unknown' }])) }.to raise_error(SlimGraphR::Error, /Unknown group/)
    expect { load_json(data.merge(edges: [{ from: 'a', to: 'missing' }])) }.to raise_error(SlimGraphR::Error, /Unknown node/)
    expect { load_json(data.merge(events: [{ date: 'Today', label: 'Wrong type' }])) }.to raise_error(SlimGraphR::Error, /Only a timeline/)
  end

  it 'rejects dedicated-type fields instead of silently discarding them from generic graphs' do
    {
      phases: [], handoffs: [], crosscuts: [], zones: [], paths: [],
      cluster: 'Cluster', connections: [], orchestration: {}
    }.each do |field, value|
      expect { load_json(data.merge(field => value)) }.to raise_error(SlimGraphR::Error, /only|accepts|cross-type/i)
    end
  end

  it 'uses events for timelines and refuses to silently discard nodes' do
    value = { type: 'timeline', events: [{ date: 'Now', label: 'Ship' }] }
    expect(load_json(value).events.first.label).to eq('Ship')
    expect { load_json(value.merge(nodes: [{ id: 'a' }])) }.to raise_error(SlimGraphR::Error, /not nodes/)
  end

  it 'bounds input size and fails with clear malformed-JSON errors' do
    expect { described_class.from_json('{') }.to raise_error(SlimGraphR::Error, /Invalid JSON/)
    expect { described_class.from_json(' ' * (described_class::MAX_BYTES + 1)) }.to raise_error(SlimGraphR::Error, /1 MiB/)
  end

  [Encoding::UTF_8, Encoding::US_ASCII, Encoding::ASCII_8BIT, Encoding::ISO_8859_1].each do |encoding|
    it "reads UTF-8 JSON bytes tagged #{encoding} without changing the caller's string" do
      source = JSON.generate(data.merge(title: 'Sales · 日本語')).force_encoding(encoding).freeze
      original_bytes = source.bytes

      expect(described_class.from_json(source).to_svg).to include('Sales · 日本語')
      expect(source.encoding).to eq(encoding)
      expect(source.bytes).to eq(original_bytes)
    end

    it "rejects invalid UTF-8 JSON bytes tagged #{encoding}" do
      source = JSON.generate(data.merge(title: 'Sales')).sub('Sales', "\xFF".b).force_encoding(encoding).freeze
      original_bytes = source.bytes

      expect { described_class.from_json(source) }.to raise_error(SlimGraphR::Error, /valid UTF-8/)
      expect(source.encoding).to eq(encoding)
      expect(source.bytes).to eq(original_bytes)
    end
  end

  it 'requires a string instead of coercing other input types' do
    [nil, {}, [], 123].each do |source|
      expect { described_class.from_json(source) }.to raise_error(SlimGraphR::Error, /String/)
    end
  end

  it 'applies the byte-size limit before interpreting the input' do
    source = "\xFF".b * (described_class::MAX_BYTES + 1)
    expect { described_class.from_json(source) }.to raise_error(SlimGraphR::Error, /1 MiB/)
  end
end
