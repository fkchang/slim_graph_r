# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:sankey, title: 'CI minutes', unit: 'minutes',
                   source_note: 'CI ledger · 2026-09-01 · includes explicit Waste') do
  stage :source, 'Input'; stage :work, 'Work'; stage :outcome, 'Outcome'
  node :ci, stage: :source, label: 'CI', value: 100
  node :test, stage: :work, label: 'Test', value: 60
  node :build, stage: :work, label: 'Build', value: 40
  node :passed, stage: :outcome, label: 'Passed', value: 90
  node :waste, stage: :outcome, label: 'Waste', value: 10
  flow :ci, :test, 60; flow :ci, :build, 40
  flow :test, :passed, 55; flow :test, :waste, 5
  flow :build, :passed, 35; flow :build, :waste, 5
end
