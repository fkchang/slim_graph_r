# frozen_string_literal: true
require 'slim_graph_r/stream_weaver'

header1 'Platform integration'
md 'Bounded partial parity with [Cathryn Lavery’s pinned Diagram Design reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-dp-integration.md).'
text 'Limits: 0–6 sources, 0–6 consumers, 2–6 platform components, 0–3 layer services, 20 wires, exactly two focal platform components, and one serving component.'

diagram :dp_integration, title: 'Platform surfaces · light' do
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

diagram :dp_integration, title: 'Platform surfaces · dark', style: :ruby, theme: :dark do
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
