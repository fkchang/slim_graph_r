# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module DataFlowReporting
    module_function
    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram :data_flow, title: 'Reporting data flow', theme: theme, style: style do
        role :engineer, 'Data Engineer', key: 'ENG'
        role :scientist, 'Data Scientist', key: 'SCI'
        role :analyst, 'Analytics Analyst', key: 'ANL'
        step :ingest, 'Ingest'; step :store, 'Store'; step :transform, 'Transform', focal: true; step :analyze, 'Analyze'; step :publish, 'Publish'
        transfer :capture, 'Capture Events', role: :engineer, step: :ingest, tool: 'NiFi ingest', detail: 'shop events → batch', input: :stream, output: :dataset
        transfer :land, 'Land Records', role: :engineer, step: :store, tool: 'Object storage', detail: 'events · orders', input: :dataset, output: :dataset
        transfer :clean, 'Clean & Model', role: :scientist, step: :transform, tool: 'Trino · notebooks', detail: 'raw → trusted table', input: :dataset, output: :table, focal: true
        transfer :curate, 'Curate Metrics', role: :scientist, step: :analyze, tool: 'Trino SQL', detail: 'conversion · revenue', input: :table, output: :table
        transfer :dashboard, 'Publish Dashboard', role: :analyst, step: :publish, tool: 'BI workspace', detail: 'metrics → decisions', input: :table, output: :file
        handoff :capture, :land, kind: :ordinary
        handoff :land, :clean, kind: :focal, label: 'RAW TABLE'
        handoff :clean, :curate, kind: :ordinary
        handoff :curate, :dashboard, kind: :publish
      end
    end
  end
end
