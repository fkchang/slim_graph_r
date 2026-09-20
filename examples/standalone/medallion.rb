# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:medallion, title: 'Survey storage tiers') do
  tier :raw, 'Raw', bucket: 'raw-bucket', tool: 'NiFi write', format: 'CSV · JSON',
       writer: 'Data Engineering', examples: ['source export']
  tier :anon, 'Anonymized', bucket: 'anon-bucket', tool: 'Trino INSERT', format: 'Iceberg',
       writer: 'Data Engineering', examples: ['stable household ID'], concern: :security
  tier :aggregate, 'Aggregated', bucket: 'metrics-bucket', tool: 'Trino', format: 'Iceberg indicators',
       writer: 'Data Science', examples: ['employment rate'], focal: true
  tier :archive, 'Archive', bucket: 'cold-bucket', tool: 'Lifecycle policy', format: 'immutable objects',
       writer: 'Data Administration', examples: ['annual snapshot'], archive: true
  promote :raw, :anon, 'REMOVE PII'
  promote :anon, :aggregate, 'AGGREGATE'
  promote :aggregate, :archive, 'LIFECYCLE'
  write_path :sql, tag: 'SQL PATH', title: 'INSERT INTO … SELECT', detail: 'set-based transforms'
end
