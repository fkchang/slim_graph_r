# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:scatter, title: 'Latency and errors', x_unit: 'ms', y_unit: '%', source_note: 'Service telemetry · 2026-08-31 · explicit axes') do
  x_scale min: -100, max: 600
  y_scale min: -1, max: 8
  point :payments, 'Payments', x: 260, y: 2.8, focal: true, annotate: true
  point :search, 'Search', x: 90, y: 0, annotate: true
  point :cache, 'Cache', x: -40, y: -0.5
end
