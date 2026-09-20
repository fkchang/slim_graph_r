# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:polar, title: 'Demand by UTC window', unit: '% of peak',
  source_note: 'Illustrative workload · 2026-09-13 · common scale 0–100') do
  scale min: 0, max: 100
  category :night, '00–06', 18
  category :morning, '06–12', 52
  category :midday, '12–18', 100, focal: true
  category :evening, '18–24', 0
end
