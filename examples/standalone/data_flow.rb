# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:data_flow, title: 'Declared reporting · pipeline') do
  role :admins, 'Admins', key: 'ADM'
  role :engineers, 'Engineers', key: 'ENG'
  role :scientists, 'Scientists', key: 'SCI'
  role :consumers, 'Consumers', key: 'CON'

  step :collect, 'Collect'
  step :store, 'Store'
  step :prepare, 'Prepare'
  step :analyse, 'Analyse', focal: true
  step :publish, 'Publish'

  transfer :setup, 'Setup', role: :admins, step: :collect, tool: 'Console'
  transfer :ingest, 'Ingest', role: :engineers, step: :collect, tool: 'SFTP', output: :dataset
  transfer :stage, 'Stage', role: :engineers, step: :prepare, tool: 'Trino', detail: 'raw → trusted table', input: :dataset, output: :table
  transfer :model, 'Model', role: :scientists, step: :analyse, tool: 'Notebook',
           input: :table, output: :file, focal: true
  transfer :query, 'Query', role: :consumers, step: :publish, tool: 'Read-only SQL', input: :table

  handoff :setup, :ingest, kind: :trigger
  handoff :stage, :model, kind: :focal, label: 'ANON DATA'
  handoff :model, :query, kind: :publish
end
