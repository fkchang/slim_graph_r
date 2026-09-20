# frozen_string_literal: true
require 'spec_helper'
require 'json'
require 'rexml/document'
require 'slim_graph_r/document'

RSpec.describe 'journey and story-map diagrams' do
  let(:journey) do
    SlimGraphR.diagram(:journey, title: 'Trial to paid', persona: 'Independent analyst') do
      stage :discover, 'Discover', sentiment: :high do
        action 'Compare plans'
        touchpoint 'Website'
      end
      stage :try, 'Try', sentiment: :medium_high do
        action 'Create a project'
        touchpoint 'App'
      end
      stage :limit, 'Hit the limit', sentiment: :low do
        action 'Upload a second project'
        touchpoint 'App'
        pain 'Usage limit is unclear'
        pain 'Upgrade route is hidden'
      end
      stage :upgrade, 'Upgrade', sentiment: :neutral do
        action 'Choose a plan'
        touchpoint 'Checkout'
      end
    end
  end

  let(:story_map) do
    SlimGraphR.diagram(:story_map, title: 'Reporting first release', persona: 'Analyst') do
      activity :find, 'Find the data' do
        step :search, 'Search catalogue'
        step :filter, 'Filter results'
      end
      activity :build, 'Build the report' do
        step :chart, 'Create chart'
      end
      activity :share, 'Share it' do
        step :send, 'Send report'
      end
      release :mvp, '2026-09-30', cut: true do
        story :saved_filter, 'Save filters', activity: :find, ticket: 'RPT-114', estimate: '3pt'
        story :templates, 'Use templates', activity: :build
      end
      release :later, 'Later' do
        story :permissions, 'Control report access', activity: :share, risk: true
      end
    end
  end

  it 'builds dedicated immutable copied records and restores nested contexts after rescued errors' do
    persona = +'Independent analyst'
    label = +'Discover'
    graph = SlimGraphR.diagram(:journey, persona: persona) do
      begin
        stage(:bad, sentiment: :low) { action 'A'; raise 'rescued' }
      rescue RuntimeError
      end
      stage(:good, label, sentiment: :high) { action 'B' }
    end
    persona.replace('changed')
    label.replace('changed')
    expect(graph.persona).to eq('Independent analyst')
    expect(graph.journey_stages.last.label).to eq('Discover')
    expect(graph).to be_frozen
    expect(graph.journey_stages).to be_frozen
    expect(graph.journey_stages.first.pains).to be_frozen
  end

  it 'requires complete ordinal sentiment, one explicit unique trough, and pains only there' do
    expect { SlimGraphR.diagram(:journey, persona: 'Role') { stage(:a, sentiment: :low) { action 'A' }; stage(:b, sentiment: :low) { action 'B' } } }
      .to raise_error(SlimGraphR::Error, /unique.*trough|tied.*lowest/i)
    expect { SlimGraphR.diagram(:journey, persona: 'Role') { stage(:a, sentiment: 1) { action 'A' }; stage(:b, sentiment: :low) { action 'B' } } }
      .to raise_error(SlimGraphR::Error, /ordinal sentiment/i)
    expect { SlimGraphR.diagram(:journey, persona: 'Role') { stage(:a, sentiment: :low) { action 'A' }; stage(:b, sentiment: :high) { action 'B'; pain 'No' } } }
      .to raise_error(SlimGraphR::Error, /pain.*trough/i)
  end

  it 'draws exact fixed ordinal coordinates, a single data curve, and an honest visible caption' do
    svg = journey.to_svg(id: 'journey-geometry')
    expect(svg).to include('data-sgr-journey="true"', 'Sentiment levels are ordinal, not measured scores')
    expect(svg).to match(/data-sgr-journey-stage="discover"[^>]*data-sgr-sentiment="high"[^>]*cx="232"[^>]*cy="72"/)
    expect(svg).to match(/data-sgr-journey-stage="limit"[^>]*data-sgr-sentiment="low"[^>]*cx="728"[^>]*cy="232"/)
    expect(svg.scan('data-sgr-sentiment-curve=').size).to eq(1)
    expect(svg).not_to include('marker-end=', 'data-sgr-connector')
    expect { REXML::Document.new(svg) }.not_to raise_error
  end

  it 'reports complete generated journey semantics and lets custom descriptions replace them' do
    generated = journey.to_svg(id: 'journey-description')
    expect(generated).to include('Independent analyst', 'Discover', 'Compare plans', 'Website', 'medium high',
                                 'Hit the limit', 'unique trough', 'Usage limit is unclear',
                                 'Sentiment levels are ordinal, not measured scores')
    custom = SlimGraphR.diagram(:journey, persona: 'Role', description: 'Replacement.') do
      stage(:a, sentiment: :high) { action 'A' }
      stage(:b, sentiment: :low) { action 'B' }
    end.to_svg(id: 'journey-custom')
    expect(custom).to include('<desc id="journey-custom-desc">Replacement.</desc>')
    expect(custom).not_to include('unique trough')
  end

  it 'preserves story narrative/release order, literal date labels, gaps, metadata, risk, and cut' do
    svg = story_map.to_svg(id: 'story-map-semantics')
    expect(svg).to include('data-sgr-story-map="true"', 'data-sgr-release="mvp"', 'data-sgr-release-label="2026-09-30"',
                           'data-sgr-release-cut="mvp"', 'data-sgr-story-risk="permissions"',
                           'data-sgr-story-metadata="saved_filter"', 'RPT-114 · 3pt', 'data-sgr-column-guide="share"')
    expect(svg.index('data-sgr-activity="find"')).to be < svg.index('data-sgr-activity="share"')
    expect(svg.index('data-sgr-release="mvp"')).to be < svg.index('data-sgr-release="later"')
    expect(svg).not_to include('data-sgr-calendar', 'data-sgr-state', 'data-sgr-sentiment')
  end

  it 'reports complete generated story-map semantics and lets custom descriptions replace them' do
    generated = story_map.to_svg(id: 'story-map-description')
    expect(generated).to include('Analyst', 'Find the data', 'Search catalogue', 'Filter results',
                                 '2026-09-30', 'release cut follows', 'Save filters', 'ticket RPT-114',
                                 'estimate 3pt', 'Control report access', 'risk', 'no calendar semantics')
    custom = SlimGraphR.diagram(:story_map, persona: 'Role', description: 'Replacement map.') do
      activity(:a) { step :one }
      activity(:b) { step :two }
      release(:now, cut: true) { story :x, activity: :a }
      release(:later) { story :y, activity: :b }
    end.to_svg(id: 'story-map-custom')
    expect(custom).to include('<desc id="story-map-custom-desc">Replacement map.</desc>')
    expect(custom).not_to include('release cut follows')
  end

  it 'enforces story-map references, one non-final cut, explicit risk, and card budgets' do
    expect do
      SlimGraphR.diagram(:story_map, persona: 'Role') do
        activity(:a) { step :one }
        activity(:b) { step :two }
        release(:now, cut: true) { story :x, activity: :missing }
        release(:later) { story :y, activity: :b }
      end
    end.to raise_error(SlimGraphR::Error, /unknown activity/i)
    expect do
      SlimGraphR.diagram(:story_map, persona: 'Role') do
        activity(:a) { step :one }
        activity(:b) { step :two }
        release(:now) { story :x, activity: :a }
        release(:later, cut: true) { story :y, activity: :b }
      end
    end.to raise_error(SlimGraphR::Error, /cut.*last/i)
  end

  it 'allows top-level forward activity references but rejects cross-nested releases and activities' do
    forward = SlimGraphR.diagram(:story_map, persona: 'Role') do
      release(:now, cut: true) { story :x, activity: :a }
      release(:later) { story :y, activity: :b }
      activity(:a) { step :one }
      activity(:b) { step :two }
    end
    expect(forward.story_releases.first.stories.first.activity).to eq('a')
    expect(forward.story_activities.map(&:id)).to eq(%w[a b])

    expect do
      SlimGraphR.diagram(:story_map, persona: 'Role') do
        activity(:a) { step :one; release(:bad, cut: true) { story :x, activity: :a } }
        activity(:b) { step :two }
        release(:now, cut: true) { story :n, activity: :a }
        release(:later) { story :l, activity: :b }
      end
    end.to raise_error(SlimGraphR::Error, /release.*inside an activity/i)

    expect do
      SlimGraphR.diagram(:story_map, persona: 'Role') do
        release(:now, cut: true) { activity(:bad) { step :nested } }
        release(:later) { story :l, activity: :b }
        activity(:a) { step :one }
        activity(:b) { step :two }
      end
    end.to raise_error(SlimGraphR::Error, /activity.*inside a release/i)

    restored = SlimGraphR.diagram(:story_map, persona: 'Role') do
      activity :a do
        begin
          release(:nested, cut: true) { story :bad, activity: :a }
        rescue SlimGraphR::Error
        end
        step :one
      end
      release :now, cut: true do
        begin
          activity(:nested) { step :bad }
        rescue SlimGraphR::Error
        end
        story :x, activity: :a
      end
      activity(:b) { step :two }
      release(:later) { story :y, activity: :b }
    end
    expect(restored.story_activities.map(&:id)).to eq(%w[a b])
    expect(restored.story_releases.map(&:id)).to eq(%w[now later])
  end

  it 'has strict equivalent JSON and rejects null, unknown, and cross-family fields' do
    root = File.expand_path('..', __dir__)
    { 'journey' => :journey_stages, 'story_map' => :story_activities }.each do |name, reader|
      ruby_graph = eval(File.read(File.join(root, "examples/standalone/#{name}.rb"), encoding: 'UTF-8'), binding, name)
      json_graph = SlimGraphR::Document.from_json(File.read(File.join(root, "examples/standalone/#{name}.json"), encoding: 'UTF-8'))
      expect(json_graph.public_send(reader)).to eq(ruby_graph.public_send(reader))
      expect(json_graph.to_svg(id: "#{name}-parity")).to eq(ruby_graph.to_svg(id: "#{name}-parity"))
    end
    base = JSON.parse(File.read(File.join(root, 'examples/standalone/journey.json'), encoding: 'UTF-8'))
    [base.merge('nodes' => []), base.merge('persona' => nil), base.merge('stages' => [base.fetch('stages').first.merge('risk' => true)])].each do |data|
      expect { SlimGraphR::Document.from_json(JSON.generate(data)) }.to raise_error(SlimGraphR::Error)
    end
  end

  it 'renders all curated styles in light and dark themes' do
    SlimGraphR::Style.names.product(%i[light dark]).each do |style, theme|
      [journey.with(style: style, theme: theme), story_map.with(style: style, theme: theme)].each do |graph|
        expect(graph.to_svg(id: "#{graph.type}-#{style}-#{theme}")).to include(
          %(data-sgr-style="#{style}"), %(data-sgr-theme="#{theme}")
        )
      end
    end
  end

  it 'raises actionable density errors rather than clipping text' do
    crowded = SlimGraphR.diagram(:journey, persona: 'Role') do
      stage(:a, sentiment: :high) { action('W' * 120) }
      stage(:b, sentiment: :low) { action 'B' }
    end
    expect { crowded.to_svg }.to raise_error(SlimGraphR::LayoutError, /action.*fit|shorten/i)
    dense = SlimGraphR.diagram(:story_map, persona: 'Role') do
      activity(:a) { step :one }
      activity(:b) { step :two }
      release(:now, cut: true) { 5.times { |i| story "s#{i}", activity: :a } }
      release(:later) { story :last, activity: :b }
    end
    expect { dense.to_svg }.to raise_error(SlimGraphR::LayoutError, /four stories.*split/i)
  end

  it 'reserves measured tracked label and stroke-safe outer boundaries' do
    scene = journey.layout
    touchpoints_width = SlimGraphR::Text.width('TOUCHPOINTS', 8, font: :mono) + 10 * 8 * 0.14
    expect(scene.label_margin - 8 - touchpoints_width).to be >= 4
    expect(scene.plot_right).to be < scene.width

    story_scene = story_map.layout
    rightmost = story_scene.activities.max_by { |entry| entry[:x] }
    expect(rightmost[:x] + rightmost[:width]).to be <= story_scene.width - 16
  end
end
