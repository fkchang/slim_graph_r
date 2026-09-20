# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:high_level, title: 'National data platform', cluster: 'Kubernetes') do
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
