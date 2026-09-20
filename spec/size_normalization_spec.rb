# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'diagram size normalization' do
  FIXTURES = %w[data_flow high_level dp_integration process swimlane story_map journey fishbone].freeze

  def fixture(name)
    path = File.expand_path("../examples/standalone/#{name}.rb", __dir__)
    TOPLEVEL_BINDING.eval(File.read(path, encoding: 'UTF-8'), path)
  end

  it 'uses the exact 14px body and 12px metadata floor without capping responsive width' do
    expected_widths = {
      'data_flow' => 1032, 'high_level' => 1000, 'dp_integration' => 1240,
      'process' => 796, 'swimlane' => 608, 'story_map' => 872,
      'journey' => 1092, 'fishbone' => 1240
    }

    FIXTURES.each do |name|
      root = fixture(name).to_svg(id: "normalized-#{name}")[/<svg[^>]+>/]
      expect(root).to include('data-sgr-display-scale="1"', %(width="#{expected_widths.fetch(name)}"),
                              %(min-width:#{expected_widths.fetch(name)}px), 'width:100%')
      expect(root).not_to include('max-width:')
    end
  end

  it 'promotes affected logical metadata roles to twelve pixels and body labels to fourteen' do
    css = FIXTURES.map { |name| fixture(name).to_svg(id: "type-#{name}")[/<style>(.*?)<\/style>/m, 1] }.join("\n")
    metadata = %w[
      sgr-fishbone-factor sgr-data-flow-payload sgr-data-flow-key sgr-data-flow-legend
      sgr-high-phase sgr-high-role sgr-high-detail sgr-high-concern sgr-high-legend
      sgr-integration-detail sgr-integration-role sgr-integration-kind sgr-integration-protocol sgr-integration-legend
      sgr-workflow-stage sgr-workflow-lane sgr-workflow-key sgr-workflow-detail sgr-workflow-tool
      sgr-workflow-trigger-label sgr-workflow-legend sgr-workflow-payload-text
      sgr-journey-eyebrow sgr-journey-persona sgr-journey-level sgr-journey-row-label
      sgr-journey-touchpoint sgr-journey-pain sgr-journey-caption sgr-journey-legend
      sgr-story-eyebrow sgr-story-persona sgr-story-release sgr-story-meta sgr-story-tag sgr-story-legend
    ]
    metadata.each { |klass| expect(css).to match(/\.#{klass}(?:[^\{]*)\{[^}]*font-size:12px/) }
    %w[sgr-data-flow-name sgr-integration-name sgr-workflow-card-name sgr-journey-action sgr-story-title].each do |klass|
      expect(css).to match(/\.#{klass}(?:[^\{]*)\{[^}]*font-size:14px/)
    end
  end

  it 'keeps the measured story-map release label inside the SVG left edge' do
    graph = fixture('story_map')
    release = graph.story_releases.first
    anchor = SlimGraphR::Layout::StoryMap::LEFT - 16
    measured = SlimGraphR::Text.width(release.label, 12, font: :mono) +
      (release.label.each_char.count - 1) * 12 * 0.14
    expect(anchor - measured).to be >= 0
    expect(graph.to_svg(id: 'story-left')).to include(%(x="#{anchor}"), 'class="sgr-story-release" text-anchor="end"')
  end

  it 'compacts ordinary and three-lower fishbones without changing their 60-degree bones or ticks' do
    graph = fixture('fishbone')
    scene = graph.layout
    expect(scene.width).to eq(1240.0)
    expect(scene.head_x).to eq(1000.0)
    expect(scene.spine_start_x).to be >= 120
    expect(scene.bones).to all(satisfy { |bone| ((bone.attach_y - bone.far_y).abs.fdiv((bone.attach_x - bone.far_x).abs) - Math.sqrt(3)).abs < 0.02 })
    expect(scene.ticks).to all(satisfy { |tick| (tick.start_x - tick.end_x).abs == 32 })

    dense = SlimGraphR.diagram(:fishbone) do
      effect 'Observed'
      category(:a, 'A', side: :above) { factor 'A' }
      category(:b, 'B', side: :below) { factor 'B' }
      category(:c, 'C', side: :below) { factor 'C' }
      category(:d, 'D', side: :below) { factor 'D' }
    end
    expect(dense.to_svg(id: 'dense-fishbone')[/<svg[^>]+>/]).to include('width="1400"')
  end
end
