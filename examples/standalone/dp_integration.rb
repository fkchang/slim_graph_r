# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:dp_integration, title: 'Declared platform · surfaces') do
  source :warehouse, 'Warehouse', kind: :database, detail: 'SQL'
  source :drop, 'Partner drop', kind: :file_drop, detail: 'SFTP'

  platform 'Data platform' do
    bar :query, 'Query service', role: 'SQL', focal: true, serves: true
    row do
      service :ingest, 'Ingest', role: 'INGEST', detail: 'ETL'
      service :store, 'Object store', role: 'STORE', detail: 'Objects', focal: true
      service :notebook, 'Notebook', role: 'ANALYSE'
    end
    bar :schedule, 'Scheduler', role: 'DAG'
  end

  consumer :reports, 'Reports', kind: :analytics, detail: 'ODBC'
  consumer :portal, 'Public portal', kind: :web, detail: 'HTTPS'
  layer_service :identity, 'Identity', kind: :identity, protocol: 'AUTH'

  wire :warehouse, :query, kind: :federated, protocol: 'JDBC'
  wire :drop, :ingest, kind: :ordinary, protocol: 'SFTP'
  wire :ingest, :store, kind: :ordinary, protocol: 'WRITE'
  wire :schedule, :ingest, kind: :trigger
  wire :query, :reports, kind: :serve, protocol: 'ODBC'
  wire :query, :portal, kind: :serve, protocol: 'HTTPS'
end
