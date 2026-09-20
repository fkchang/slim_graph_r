# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:line, title: 'Incidents', unit: 'incidents/day', source_note: 'Operations log · 2026-01 · display precision 3') do
  x_axis :time, domain: %w[2026-01-01 2026-01-02 2026-01-11 2026-01-21]
  scale min: 0, max: 12
  series :api, 'API', focal: true do
    point 8
    gap reason: 'telemetry outage'
    point 3
    point 5
  end
end
