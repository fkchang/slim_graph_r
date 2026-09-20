# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:radar, title: 'Backend scorecard', unit: 'score / 10',
  source_note: 'Review rubric · 2026-09-13 · already-common 0–10 score') do
  scale min: 0, max: 10
  criterion :latency, 'Latency'
  criterion :recovery, 'Recovery'
  criterion :cost, 'Cost'
  entity :postgres, 'Postgres', values: { latency: 8, recovery: 9, cost: 6 }, focal: true
  entity :sqlite, 'SQLite', values: { latency: 9, recovery: 0, cost: 10 }
end
