# frozen_string_literal: true

require 'slim_graph_r'

module ParityFixtures
  module QuadrantPublicationPriorities
    AXES = { horizontal: ['LOW EFFORT', 'HIGH EFFORT'], vertical: ['LOW IMPACT', 'HIGH IMPACT'] }.freeze
    QUADRANTS = %w[DO_FIRST MAJOR_PROJECTS QUICK_WINS AVOID].freeze
    ITEMS = ['Schematic skill v4', 'Update changelog', 'Design v4 refresh', 'New publication', 'Fix footer link', 'Update OG tags', 'Rewrite build pipeline', 'Port to Nuxt'].freeze

    module_function

    def diagram(**options)
      SlimGraphR.diagram(:quadrant, title: 'Content ideas · Impact × Effort', **options) do
        horizontal_axis low: 'LOW EFFORT', high: 'HIGH EFFORT'
        vertical_axis low: 'LOW IMPACT', high: 'HIGH IMPACT'
        region :upper_left, 'DO FIRST'; region :upper_right, 'MAJOR PROJECTS'
        region :lower_left, 'QUICK WINS'; region :lower_right, 'AVOID'
        item :schematic, ITEMS[0], x: -0.737, y: 0.647, focal: true
        item :changelog, ITEMS[1], x: -0.474, y: 0.294
        item :refresh, ITEMS[2], x: 0.316, y: 0.647
        item :publication, ITEMS[3], x: 0.684, y: 0.412
        item :footer, ITEMS[4], x: -0.632, y: -0.412
        item :og_tags, ITEMS[5], x: -0.368, y: -0.765
        item :pipeline, ITEMS[6], x: 0.368, y: -0.765
        item :nuxt, ITEMS[7], x: 0.737, y: -0.412
      end
    end
  end
end
