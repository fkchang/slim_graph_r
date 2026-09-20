# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'

use_layout :full
header1 'Cartesian quantities without hidden repair'
text 'Original values drive every mark. Zero, negative values, elapsed time, ordinal spacing, and gaps stay explicit.'

diagram :bar, title: 'Net bookings', unit: 'USD millions' do
  category :north, 'North', 24
  category :south, 'South', -6
  category :online, 'Online', 0, focal: true
end

diagram :line, title: 'Incidents', unit: 'incidents/day', theme: :dark do
  x_axis :time, domain: %w[2026-01-01 2026-01-02 2026-01-11 2026-01-21]
  series :api, 'API', focal: true do
    point 8
    gap reason: 'telemetry outage'
    point 3
    point 5
  end
end

diagram :scatter, title: 'Latency and errors', x_unit: 'ms', y_unit: '%' do
  x_scale min: -100, max: 600
  y_scale min: -1, max: 8
  point :payments, 'Payments', x: 260, y: 2.8, focal: true, annotate: true
  point :search, 'Search', x: 90, y: 0, annotate: true
  point :cache, 'Cache', x: -40, y: -0.5
end
