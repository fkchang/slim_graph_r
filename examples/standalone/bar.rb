# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:bar, title: 'Net bookings', unit: 'USD millions', source_note: 'Finance ledger · 2026-08-31 · explicit bounds −10 to 30') do
  scale min: -10, max: 30
  category :north, 'North', 24
  category :south, 'South', -6
  category :online, 'Online', 0, focal: true
end
