# frozen_string_literal: true
require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'bounded medallion diagrams' do
  it 'builds a frozen explicit focal model with optional final archive and adjacent promotions' do
    graph = SlimGraphR.diagram(:medallion) do
      tier :raw, bucket: 'raw', tool: 'NiFi', format: 'JSON', writer: 'DE', examples: ['source']
      tier :clean, bucket: 'clean', tool: 'Trino', format: 'Iceberg', writer: 'DE', examples: ['rows'], concern: :quality
      tier :gold, bucket: 'gold', tool: 'dbt', format: 'Iceberg', writer: 'DS', examples: ['metric'], focal: true
      tier :cold, bucket: 'cold', tool: 'Policy', format: 'Objects', writer: 'DA', examples: ['snapshot'], archive: true
      promote :raw, :clean, 'VALIDATE'
      promote :clean, :gold, 'AGGREGATE'
      promote :gold, :cold, 'LIFECYCLE'
      write_path :sql, tag: 'SQL PATH', title: 'INSERT SELECT', detail: 'set based', concern: :analysis
    end
    expect(graph.tiers.count(&:focal)).to eq(1)
    expect(graph.tiers.last.archive).to be(true)
    expect(graph.tiers.first.examples).to be_frozen
    expect(graph.promotions).to all(be_frozen)
  end

  it 'keeps strict JSON and Ruby parity without inferring archive from classic names' do
    tiers = [
      { id: 'bronze', bucket: 'a', tool: 'one', format: 'JSON', writer: 'DE', examples: ['raw'] },
      { id: 'silver', bucket: 'b', tool: 'two', format: 'Parquet', writer: 'DE', examples: ['clean'], focal: true },
      { id: 'gold', bucket: 'c', tool: 'three', format: 'Iceberg', writer: 'DS', examples: ['metric'] }
    ]
    data = { type: 'medallion', tiers: tiers, promotions: [
      { from: 'bronze', to: 'silver', label: 'CLEAN' }, { from: 'silver', to: 'gold', label: 'PUBLISH' }
    ] }
    graph = SlimGraphR::Document.from_json(JSON.generate(data))
    expect(graph.tiers.last.archive).to be(false)
    expect { SlimGraphR::Document.from_json(JSON.generate(data.merge(direction: 'right'))) }.to raise_error(SlimGraphR::Error, /direction/)
    expect { SlimGraphR::Document.from_json(JSON.generate(data.merge(tiers: tiers.map(&:dup).tap { |x| x[0][:color] = '#fff' }))) }.to raise_error(SlimGraphR::Error)
  end

  it 'keeps the executable standalone Ruby and JSON example equivalent' do
    root = File.expand_path('../examples/standalone', __dir__)
    ruby = eval(File.read(File.join(root, 'medallion.rb'), encoding: 'UTF-8'), binding, File.join(root, 'medallion.rb'))
    json = SlimGraphR::Document.from_json(File.read(File.join(root, 'medallion.json'), encoding: 'UTF-8'))
    expect(json.to_svg(id: 'medallion-example')).to eq(ruby.to_svg(id: 'medallion-example'))
  end

  it 'uses fixed card geometry, 100px right pad, cubic adjacent arcs, and connector-first z-order' do
    graph = SlimGraphR.diagram(:medallion) do
      tier :raw, bucket: 'raw', tool: 'one', format: 'JSON', writer: 'DE', examples: ['a']
      tier :clean, bucket: 'clean', tool: 'two', format: 'Parquet', writer: 'DE', examples: ['b'], concern: :quality
      tier :gold, bucket: 'gold', tool: 'three', format: 'Iceberg', writer: 'DS', examples: ['c'], focal: true
      promote :raw, :clean, 'VALIDATE'
      promote :clean, :gold, 'PUBLISH'
    end
    scene = graph.layout
    expect([scene.width, scene.height]).to eq([16 + 3 * 172 + 2 * 16 + 100, 476])
    expect(scene.medallion_cards.map { |x| x[:rect] }).to eq([[16, 80, 188, 460], [204, 80, 376, 460], [392, 80, 564, 460]])
    expect(scene.medallion_arcs.map { |x| x[:style] }).to eq([:quality, :focal])
    expect(scene.medallion_arcs.first.values_at(:control1, :control2)).to eq([[102.0, 0], [290.0, 0]])
    svg = graph.to_svg(id: 'medallion-geometry')
    expect(svg.index('data-sgr-medallion-promotion')).to be < svg.index('data-sgr-medallion-tier')
    expect(svg).to include(' C ', 'marker-end="url(#medallion-geometry-arrow-quality)"')
    expect(svg).to include('data-sgr-medallion-field="bucket" style="fill:var(--sgr-concern-quality)"')
    header = REXML::XPath.first(REXML::Document.new(svg), '//*[@data-sgr-medallion-header="raw"]')
    expect([header.attributes['y'], header.attributes['height']]).to eq(['80', '40'])
  end

  it 'applies target concern, focal, and archive precedence without accenting focal output' do
    graph = SlimGraphR.diagram(:medallion) do
      tier :raw, bucket: 'a', tool: 'one', format: 'JSON', writer: 'DE', examples: ['a']
      tier :secure, bucket: 'b', tool: 'two', format: 'Iceberg', writer: 'DE', examples: ['b'], concern: :security
      tier :focus, bucket: 'c', tool: 'three', format: 'Iceberg', writer: 'DS', examples: ['c'], focal: true
      tier :archive, bucket: 'd', tool: 'four', format: 'Objects', writer: 'DA', examples: ['d'], archive: true
      promote :raw, :secure, 'SECURE'
      promote :secure, :focus, 'AGGREGATE'
      promote :focus, :archive, 'LIFECYCLE'
    end
    arcs = graph.layout.medallion_arcs
    expect(arcs.map { |x| [x[:style], x[:dashed]] }).to eq([[:security, false], [:focal, false], [:normal, true]])
  end

  it 'validates tier count, explicit focus, archive placement, concerns, examples, and adjacent promotions' do
    build = lambda do |&extra|
      SlimGraphR.diagram(:medallion) do
        tier :a, bucket: 'a', tool: 'a', format: 'a', writer: 'a', examples: ['a']
        tier :b, bucket: 'b', tool: 'b', format: 'b', writer: 'b', examples: ['b'], focal: true
        tier :c, bucket: 'c', tool: 'c', format: 'c', writer: 'c', examples: ['c']
        instance_eval(&extra) if extra
      end
    end
    expect { build.call { promote :a, :c, 'SKIP'; promote :c, :b, 'BACK' } }.to raise_error(SlimGraphR::Error, /adjacent tier/)
    expect do
      SlimGraphR.diagram(:medallion) do
        tier :a, bucket: 'a', tool: 'a', format: 'a', writer: 'a', examples: ['a'], archive: true
        tier :b, bucket: 'b', tool: 'b', format: 'b', writer: 'b', examples: ['b'], focal: true
        tier :c, bucket: 'c', tool: 'c', format: 'c', writer: 'c', examples: ['c']
        promote :a, :b, 'NEXT'; promote :b, :c, 'NEXT'
      end
    end.to raise_error(SlimGraphR::Error, /archive tier must be final/i)
    expect { build.call { promote :a, :b, 'lower'; promote :b, :c, 'NEXT' } }.to raise_error(SlimGraphR::Error, /uppercase/)
    expect { SlimGraphR.diagram(:medallion) { tier :a, bucket: 'a', tool: 'a', format: 'a', writer: 'a', examples: [] } }.to raise_error(SlimGraphR::Error, /one or two/)
  end

  it 'bounds two concerns across tiers and write paths and rejects arbitrary color and null JSON' do
    data = {
      type: 'medallion', tiers: [
        { id: 'a', bucket: 'a', tool: 'a', format: 'a', writer: 'a', examples: ['a'], concern: 'security' },
        { id: 'b', bucket: 'b', tool: 'b', format: 'b', writer: 'b', examples: ['b'], focal: true },
        { id: 'c', bucket: 'c', tool: 'c', format: 'c', writer: 'c', examples: ['c'] }
      ], promotions: [{ from: 'a', to: 'b', label: 'NEXT' }, { from: 'b', to: 'c', label: 'NEXT' }],
      write_paths: [{ id: 'one', tag: 'ONE', title: 'One', detail: 'one', concern: 'quality' },
                    { id: 'two', tag: 'TWO', title: 'Two', detail: 'two', concern: 'analysis' }]
    }
    expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error, /at most two concerned/)
    [data.merge(write_paths: [{ id: 'x', tag: nil, title: 'x', detail: 'x' }]),
     data.merge(tiers: data[:tiers].map(&:dup).tap { |x| x[0][:color] = '#fff' })].each do |bad|
      expect { SlimGraphR::Document.from_json(JSON.generate(bad)) }.to raise_error(SlimGraphR::Error)
    end
  end

  it 'wraps fields with portable tspans, rejects overflow, and describes every semantic field' do
    graph = SlimGraphR.diagram(:medallion, title: 'Données') do
      tier :raw, 'Brut', bucket: 'raw-bucket', tool: 'NiFi write', format: 'CSV · JSON', writer: 'Data Engineering', examples: ['source export']
      tier :anon, 'Anonymisé', bucket: 'anon-bucket', tool: 'Trino INSERT', format: 'Iceberg', writer: 'Data Engineering', examples: ['stable household ID'], focal: true
      tier :gold, 'Agrégé', bucket: 'metrics', tool: 'Trino', format: 'Iceberg', writer: 'Data Science', examples: ['employment rate']
      promote :raw, :anon, 'REMOVE PII'
      promote :anon, :gold, 'AGGREGATE'
    end
    svg = graph.to_svg
    expect(svg).to include('<tspan', 'bucket raw-bucket', 'writer Data Engineering', 'REMOVE PII', 'Anonymisé')
    expect do
      SlimGraphR.diagram(:medallion) do
        tier :a, bucket: 'W' * 100, tool: 'a', format: 'a', writer: 'a', examples: ['a']
        tier :b, bucket: 'b', tool: 'b', format: 'b', writer: 'b', examples: ['b'], focal: true
        tier :c, bucket: 'c', tool: 'c', format: 'c', writer: 'c', examples: ['c']
        promote :a, :b, 'NEXT'; promote :b, :c, 'NEXT'
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /more than two lines/)
    expect do
      SlimGraphR.diagram(:medallion) do
        tier :a, 'W' * 30, bucket: 'a', tool: 'a', format: 'a', writer: 'a', examples: ['a']
        tier :b, bucket: 'b', tool: 'b', format: 'b', writer: 'b', examples: ['b'], focal: true
        tier :c, bucket: 'c', tool: 'c', format: 'c', writer: 'c', examples: ['c']
        promote :a, :b, 'NEXT'; promote :b, :c, 'NEXT'
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /40px header.*shorten/)
    expect do
      SlimGraphR.diagram(:medallion) do
        tier :a, bucket: 'a', tool: 'a', format: 'a', writer: 'a', examples: ['a']
        tier :b, bucket: 'b', tool: 'b', format: 'b', writer: 'b', examples: ['b'], focal: true
        tier :c, bucket: 'c', tool: 'c', format: 'c', writer: 'c', examples: ['c']
        promote :a, :b, 'NEXT'; promote :b, :c, 'NEXT'
        write_path :x, tag: 'W' * 200, title: 'Title', detail: 'Detail'
      end.to_svg
    end.to raise_error(SlimGraphR::LayoutError, /distinct lanes.*shorten/)
  end

  it 'allocates measured nonoverlapping lanes for canonical SQL and notebook write paths' do
    graph = SlimGraphR.diagram(:medallion) do
      tier :a, bucket: 'a', tool: 'a', format: 'a', writer: 'a', examples: ['a']
      tier :b, bucket: 'b', tool: 'b', format: 'b', writer: 'b', examples: ['b'], focal: true
      tier :c, bucket: 'c', tool: 'c', format: 'c', writer: 'c', examples: ['c']
      promote :a, :b, 'NEXT'; promote :b, :c, 'NEXT'
      write_path :sql, tag: 'SQL PATH', title: 'INSERT SELECT', detail: 'set based'
      write_path :notebook, tag: 'NOTEBOOK PATH', title: 'Spark write', detail: 'dataframe output'
    end
    graph.layout.medallion_paths.each do |entry|
      expect(entry[:rect][0] + 8 + entry[:tag_width]).to be < entry[:title_x]
      expect(entry[:title_x] + SlimGraphR::Text.width(entry[:path].title, 11)).to be <= entry[:rect][2] - 12
    end
    expect(graph.to_svg).to include('SQL PATH', 'NOTEBOOK PATH')
  end

  it 'renders all curated style and theme combinations with semantic palette tokens' do
    graph = SlimGraphR.diagram(:medallion) do
      tier :a, bucket: 'a', tool: 'a', format: 'a', writer: 'a', examples: ['a'], concern: :product
      tier :b, bucket: 'b', tool: 'b', format: 'b', writer: 'b', examples: ['b'], focal: true
      tier :c, bucket: 'c', tool: 'c', format: 'c', writer: 'c', examples: ['c']
      promote :a, :b, 'NEXT'; promote :b, :c, 'NEXT'
    end
    %i[editorial ruby blueprint mono].product(%i[light dark auto]).each do |style, theme|
      svg = graph.with(style: style, theme: theme).to_svg
      expect(svg).to include(%(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}"), '--sgr-concern-product:')
    end
  end
end
