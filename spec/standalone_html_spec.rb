# frozen_string_literal: true

require 'spec_helper'
require_relative '../examples/parity/architecture_content_site'
require_relative '../examples/parity/deployment_checkout_service'
require_relative '../examples/parity/process_survey_build'
require_relative '../examples/parity/gantt_platform_launch'
require_relative '../examples/parity/kanban_platform_team'
require_relative '../examples/parity/dp_security_matrix_platform'
require_relative '../examples/parity/tree_skill_taxonomy'

RSpec.describe 'standalone HTML containment' do
  STANDALONE_FIXTURES = {
    architecture: ParityFixtures::ArchitectureContentSite,
    deployment: ParityFixtures::DeploymentCheckoutService,
    process: ParityFixtures::ProcessSurveyBuild,
    gantt: ParityFixtures::GanttPlatformLaunch,
    kanban: ParityFixtures::KanbanPlatformTeam,
    dp_security_matrix: ParityFixtures::DPSecurityMatrixPlatform,
    tree: ParityFixtures::TreeSkillTaxonomy
  }.freeze
  PROFILES = {
    'minimal-light' => { style: :minimal, theme: :light },
    'minimal-dark' => { style: :minimal, theme: :dark },
    'full-editorial' => { style: :editorial, theme: :light }
  }.freeze

  def svg_tag(markup)
    markup.match(/<svg\b[^>]*>/)[0]
  end

  def attribute(markup, name)
    markup.match(/(?:\A|\s)#{Regexp.escape(name)}="([^"]*)"/)[1]
  end

  STANDALONE_FIXTURES.each do |type, fixture|
    profiles = type == :tree ? PROFILES.slice('full-editorial') : PROFILES
    profiles.each do |profile_name, options|
      it "contains the #{type} #{profile_name} fixture without changing its SVG geometry" do
        diagram = fixture.diagram(**options)
        standalone = diagram.to_html
        standalone_svg = svg_tag(standalone)
        direct_svg = svg_tag(diagram.to_svg(id: "intrinsic-#{type}-#{profile_name}"))

        expect(standalone).to include('<meta name="viewport" content="width=device-width, initial-scale=1">')
        expect(standalone).to include(
          '<div class="sgr-scroll-container" data-sgr-scroll-container="true" role="region" tabindex="0"',
          %(aria-label="#{CGI.escapeHTML(diagram.title)}"),
          'display:block;box-sizing:border-box;width:100%;max-width:100%;overflow-x:auto;overflow-y:hidden;overscroll-behavior-inline:contain'
        )

        %w[viewBox width height style].each do |name|
          expect(attribute(standalone_svg, name)).to eq(attribute(direct_svg, name))
        end
        expect(attribute(standalone_svg, 'style')).to match(/min-width:\d+px/)
      end
    end
  end

  it 'keeps a readable intrinsic SVG width scrollable inside a narrow document region' do
    diagram = ParityFixtures::KanbanPlatformTeam.diagram(style: :minimal, theme: :dark)
    html = diagram.to_html
    svg = svg_tag(html)

    expect(attribute(svg, 'width').to_i).to be > 320
    expect(attribute(svg, 'style')).to include('width:100%;height:auto', "min-width:#{attribute(svg, 'width')}px")
    expect(attribute(svg, 'style')).not_to include('max-width:')
    expect(html).to include('width:100%;max-width:100%;overflow-x:auto')
    expect(html).not_to include('transform:scale', 'zoom:')
  end

  it 'escapes the scroll region name while retaining the SVG accessible name and description' do
    diagram = SlimGraphR.diagram(:architecture, title: 'Sales & "Support"') do
      node :reader
      node :origin
      flow :reader, :origin
    end
    html = diagram.to_html

    expect(html).to include('aria-label="Sales &amp; &quot;Support&quot;"', 'role="img"', 'aria-labelledby=')
    expect(html).to include('<title ', 'Sales &amp; &quot;Support&quot;</title>', '<desc ')
  end
end
