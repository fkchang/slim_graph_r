require 'spec_helper'
require 'slim_graph_r/document'

RSpec.describe 'Faithful calendar timelines' do
  def build(dates, **options)
    SlimGraphR.diagram(:timeline, **options) do
      dates.each_with_index { |date, i| event date, "Event #{i + 1}" }
    end
  end

  it 'sorts out-of-order dates while preserving exact elapsed-day ratios and the original model' do
    dates = %w[2026-02-10 2026-01-11 2026-01-01]
    graph = build(dates, scale: :date)
    scene = graph.layout
    expect(scene.events.map { |e| e[:date] }).to eq(dates.reverse)
    xs = scene.events.map { |e| e[:x] }
    expect((xs[2] - xs[1]) / (xs[1] - xs[0])).to be_within(1e-10).of(3)
    expect(graph.events.map(&:date)).to eq(dates)
    expect(scene.axis.values_at(:first, :last)).to eq(%w[2026-01-01 2026-02-10])
  end

  it 'compacts the sparse atlas calendar without changing its elapsed-day geometry or clipping endpoints' do
    graph = build(%w[2026-01-08 2026-02-04 2026-03-21], scale: :date)
    scene = graph.layout
    xs = scene.events.map { |event| event[:x] }

    expect(scene.width).to be <= 900
    expect(xs[1] - xs[0]).to be_within(1e-10).of((xs[2] - xs[0]) * 27.fdiv(72))
    expect(xs[2] - xs[1]).to be_within(1e-10).of((xs[2] - xs[0]) * 45.fdiv(72))
    expect(scene.axis[:ticks].map { |tick| tick[:label] }).to eq(%w[2026-01-08 2026-02-07 2026-03-21])
    expect(scene.axis[:ticks].last).to include(x: xs.last, label: '2026-03-21')
    expect(scene.events.last[:date]).to eq('2026-03-21')
    expect(scene.axis[:callouts].last[:date]).to eq('2026-03-21')
    expect(scene.axis[:callouts].first[:rect][0]).to be >= 0
    expect(scene.axis[:callouts].last[:rect][2]).to be <= scene.width
    expect(graph.to_svg).to include('data-sgr-date="2026-03-21"', '>2026-03-21</text>')
  end

  it 'never nudges close dates to a minimum aesthetic gap' do
    graph = build(%w[2026-01-01 2026-01-03 2026-02-20], scale: :date)
    xs = graph.layout.events.map { |e| e[:x] }
    expect(xs[1] - xs[0]).to be_within(1e-10).of((xs[2] - xs[0]) * 2.fdiv(50))
  end

  it 'groups simultaneous events at one marker without dropping their content or source order' do
    graph = build(%w[2026-01-08 2026-01-08 2026-01-10], scale: :date)
    scene = graph.layout
    expect(scene.events[0][:x]).to eq(scene.events[1][:x])
    expect(scene.axis[:callouts].size).to eq(2)
    expect(scene.axis[:callouts].first[:entries].map { |e| e[:event].label }).to eq(['Event 1', 'Event 2'])
    xml = REXML::Document.new(graph.to_svg)
    markers = REXML::XPath.match(xml, '//*[@data-sgr-date]')
    expect(markers.size).to eq(2)
    expect(markers.first['data-sgr-event-count']).to eq('2')
  end

  it 'shows a single-date domain without inventing an elapsed interval' do
    graph = build(%w[2026-01-08 2026-01-08], scale: :date)
    scene = graph.layout
    expect(scene.axis[:x1]).to eq(scene.axis[:x2])
    expect(scene.axis[:ticks].size).to eq(1)
    expect(graph.to_svg).to include('simultaneous events share one marker')
  end

  it 'uses strict complete Gregorian calendar dates and handles leap days' do
    %w[01-08 September 2026 2026-02-29 2026-01-08T12:00:00Z].each do |date|
      expect { build([date], scale: :date).layout }.to raise_error(SlimGraphR::Error, /valid YYYY-MM-DD/)
      expect(build([date]).layout.axis[:mode]).to eq(:ordered)
    end
    xs = build(%w[2024-02-28 2024-02-29 2024-03-01]).layout.events.map { |e| e[:x] }
    expect(xs[1] - xs[0]).to eq(xs[2] - xs[1])
  end

  it 'keeps all long callouts, date ticks and leaders clear without moving the markers' do
    graph = SlimGraphR.diagram(:timeline, scale: :date) do
      %w[2026-01-01 2026-01-10 2026-01-19 2026-01-28 2026-02-06].each do |date|
        event date, 'A substantial milestone whose full meaning matters', detail: 'All of this explanation must fit without touching the axis or obscuring another event.'
      end
    end
    scene = graph.layout
    groups = scene.axis[:callouts]
    groups.combination(2) { |a, b| expect(SlimGraphR::Layout::Geometry.overlaps?(a[:rect], b[:rect])).to be(false) }
    groups.each do |group|
      x, y, r, b = group[:rect]
      expect(x).to be >= 0
      expect(y).to be >= 0
      expect(r).to be <= scene.width
      expect(b).to be < scene.height - 32
      expect(y > scene.axis[:y] + 40 || b < scene.axis[:y] - 8).to be(true)
      group[:leader].each_cons(2) do |a, z|
        groups.reject { |other| other.equal?(group) }.each do |other|
          expect(SlimGraphR::Layout::Geometry.blocked?(a, z, other[:rect])).to be(false)
        end
      end
    end
    expect { graph.to_svg }.not_to raise_error
  end

  it 'rejects visually indistinguishable distinct dates instead of silently distorting them' do
    graph = build(%w[2026-01-01 2026-01-02 2026-12-31], scale: :date)
    expect { graph.to_svg }.to raise_error(SlimGraphR::LayoutError, /too close/)
    expect(graph.with(scale: :ordered).to_svg).to include('spacing does not measure time')
  end

  it 'keeps ordered mode explicit, validates overrides, and prevents scale options on other types' do
    graph = build(%w[2026-02-01 Next 2026-01-01])
    expect(graph.layout.axis[:mode]).to eq(:ordered)
    expect(graph.layout.events.map { |e| e[:event].date }).to eq(%w[2026-02-01 Next 2026-01-01])
    expect { graph.with(scale: :bogus) }.to raise_error(SlimGraphR::Error, /Timeline scale/)
    expect { SlimGraphR.diagram(:flowchart, scale: :date) { step :a } }.to raise_error(SlimGraphR::Error, /only to timelines/)
    expect { SlimGraphR.diagram { node :a }.with(scale: :date) }.to raise_error(SlimGraphR::Error, /only to timelines/)
  end

  it 'keeps ticks readable and reports the same chronology through JSON and accessible output' do
    input = { type: 'timeline', scale: 'date', events: [{ date: '2026-02-10', label: 'Last' }, { date: '2026-01-01', label: 'First' }] }
    graph = SlimGraphR::Document.from_json(JSON.generate(input))
    scene = graph.layout
    scene.axis[:ticks].each_cons(2) { |a, b| expect(b[:x] - a[:x]).to be >= 112 }
    desc = REXML::XPath.first(REXML::Document.new(graph.to_svg), '//*[local-name()="desc"]').text
    expect(desc).to include('linear elapsed-day spacing')
    expect(desc.index('First')).to be < desc.index('Last')
  end
end
