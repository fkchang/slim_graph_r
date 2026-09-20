# frozen_string_literal: true
require 'slim_graph_r/stream_weaver'

header1 'Data flow'
md 'Bounded partial parity with [Cathryn Lavery’s pinned Diagram Design reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-data-flow.md).'
text 'Limits: 2–4 roles, 2–6 steps, 2–16 transfers, up to 20 handoffs, and one linked focal claim.'

diagram :data_flow, title: 'Reporting pipeline · light' do
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
  transfer :stage, 'Stage', role: :engineers, step: :prepare, tool: 'Trino', input: :dataset, output: :table
  transfer :model, 'Model', role: :scientists, step: :analyse, tool: 'Notebook', input: :table, output: :file, focal: true
  transfer :query, 'Query', role: :consumers, step: :publish, tool: 'Read-only SQL', input: :table
  handoff :setup, :ingest, kind: :trigger
  handoff :stage, :model, kind: :focal, label: 'ANON DATA'
  handoff :model, :query, kind: :publish
end

diagram :data_flow, title: 'Reporting pipeline · dark', theme: :dark do
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
  transfer :stage, 'Stage', role: :engineers, step: :prepare, tool: 'Trino', input: :dataset, output: :table
  transfer :model, 'Model', role: :scientists, step: :analyse, tool: 'Notebook', input: :table, output: :file, focal: true
  transfer :query, 'Query', role: :consumers, step: :publish, tool: 'Read-only SQL', input: :table
  handoff :setup, :ingest, kind: :trigger
  handoff :stage, :model, kind: :focal, label: 'ANON DATA'
  handoff :model, :query, kind: :publish
end
