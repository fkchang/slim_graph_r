# frozen_string_literal: true
require 'slim_graph_r/stream_weaver'

diagram :high_level, title: 'National data platform · paired concerns', cluster: 'Kubernetes' do
  phase :sources, 'Data sources' do
    source :postgres, 'PostgreSQL', type: :db, detail: 'Registry'
    source :drop, 'SFTP drop', type: :ftp
  end
  phase :ingest, 'Ingestion' do
    component :nifi, 'NiFi', role: 'COLL'
  end
  phase :storage, 'Storage' do
    component :minio, 'MinIO', role: 'STORE', focal: true
    component :trino, 'Trino', role: 'VIRT'
  end
  phase :consume, 'Visualization' do
    component :superset, 'Superset', role: 'DASH'
  end
  connect :postgres, :nifi
  connect :drop, :nifi
  connect :nifi, :minio
  connect :minio, :superset
  orchestrate :airflow, 'Airflow', detail: 'Apache Airflow', targets: %i[nifi minio superset]
  crosscut :identity, 'Identity', detail: 'LDAP · OIDC', concern: 'Security'
end

diagram :high_level, title: 'Research data path · horizontal', style: :ruby, theme: :dark do
  phase :inputs, 'Inputs' do
    source :forms, 'Web forms', type: :web
    source :partner, 'Partner API', type: :api
  end
  phase :prepare, 'Prepare' do
    component :collector, 'Collector', role: 'COLL'
  end
  phase :analyze, 'Analyze' do
    component :warehouse, 'Warehouse', role: 'STORE', focal: true
  end
  phase :publish, 'Publish' do
    component :portal, 'Public portal', role: 'VIEW'
  end
  connect :forms, :collector
  connect :partner, :collector
  connect :collector, :warehouse
  connect :warehouse, :portal
end
