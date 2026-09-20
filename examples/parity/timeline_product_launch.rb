# frozen_string_literal: true

require 'slim_graph_r'

# Semantic counterpart to Diagram Design's pinned product-milestone timeline.
# The upstream source names months but not days; the first day of each named
# month only encodes those month-granular positions for SlimGraphR's honest
# date scale. The displayed milestone labels and chronology are pinned-source
# content, not a generic timeline example.
module ParityFixtures
  module TimelineProductLaunch
    module_function

    def diagram(theme: :light, style: :editorial)
      profile = style.to_sym
      unless %i[editorial minimal].include?(profile)
        raise ArgumentError, 'Timeline product-launch parity fixture supports minimal and full-editorial profiles'
      end

      SlimGraphR.diagram :timeline,
                         title: 'Product launch · fourteen months',
                         description: 'Product milestones from the first post in February 2025 through three design versions and the schematic skill in April 2026.',
                         theme: theme,
                         style: profile,
                         scale: :date do
        event '2025-02-01', 'First post', detail: 'FEB 2025'
        event '2025-04-01', 'Design v1', detail: 'APR 2025'
        event '2025-09-01', 'Design v2', detail: 'SEP 2025 · typography pass'
        event '2026-01-01', 'Design v3', detail: 'JAN 2026 · complexity budget', emphasis: true
        event '2026-04-01', 'Schematic skill', detail: 'APR 2026 · NOW · eight diagram types', emphasis: true
      end
    end
  end
end
