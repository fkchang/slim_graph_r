# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module SankeyCIBudget
    module_function
    def diagram(**options)
      SlimGraphR.diagram(:sankey, title: 'CI compute budget · a month of pipeline minutes', unit: 'min', **options) do
        stage :budget, 'BUDGET'; stage :test, 'TEST STAGE'; stage :outcome, 'OUTCOME'
        node :ci, stage: :budget, label: 'CI minutes', value: 12_000
        node :unit, stage: :test, label: 'Unit tests', value: 5_200
        node :e2e, stage: :test, label: 'E2E', value: 4_000
        node :build, stage: :test, label: 'Build', value: 2_000
        node :lint, stage: :test, label: 'Lint', value: 800
        node :flaked, stage: :outcome, label: 'Flaked', value: 1_000
        node :passed, stage: :outcome, label: 'Passed', value: 9_400
        node :failed, stage: :outcome, label: 'Failed', value: 1_600
        flow :ci, :unit, 5_200; flow :ci, :e2e, 4_000; flow :ci, :build, 2_000; flow :ci, :lint, 800
        flow :unit, :flaked, 800, focal: true; flow :unit, :passed, 4_400
        flow :e2e, :flaked, 200, focal: true; flow :e2e, :passed, 3_200; flow :e2e, :failed, 600
        flow :build, :passed, 1_800; flow :build, :failed, 200; flow :lint, :failed, 800
      end
    end
  end
end
