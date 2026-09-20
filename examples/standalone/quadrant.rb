# frozen_string_literal: true
require 'slim_graph_r'

module SlimGraphRQuadrant
  DIAGRAM = SlimGraphR.diagram(:quadrant, title: 'Platform priorities · 優先順位') do
    horizontal_axis low: 'EASY', high: 'HARD'
    vertical_axis low: 'LOW IMPACT', high: 'HIGH IMPACT'
    item :cache, 'Cache migration', x: 0.72, y: 0.66, focal: true
    item :audit, 'Audit trail', x: -0.58, y: 0.34
    item :cleanup, 'Lint cleanup', x: -0.42, y: -0.46
    item :docs, 'Documentation', x: 0.35, y: -0.62
  end
end

if $PROGRAM_NAME == __FILE__
  File.write(ARGV.fetch(0, 'quadrant.svg'), SlimGraphRQuadrant::DIAGRAM.to_svg,
             mode: 'w', encoding: 'UTF-8')
end

SlimGraphRQuadrant::DIAGRAM
