# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module DPIntegrationPlatform
    module_function
    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram :dp_integration, title: 'Generic data platform integration topology', theme: theme, style: style do
        source :crm, 'CRM', kind: :database, detail: 'customer records'
        source :pos_exports, 'POS exports', kind: :file_drop, detail: 'daily CSV batches'
        source :event_stream, 'Event stream', kind: :legacy, detail: 'near-real-time events'

        platform 'Data platform' do
          bar :orchestrator, 'Orchestrator', role: 'DAG', detail: 'schedules · retries · lineage'
          row do
            service :object_storage, 'Object storage', role: 'STORE', detail: 'versioned data objects', focal: true
            service :query_engine, 'Query engine', role: 'SQL', detail: 'federated SQL access', focal: true, serves: true
          end
        end

        consumer :bi_tool, 'BI tool', kind: :analytics, detail: 'dashboards · reports'
        consumer :notebooks, 'Notebooks', kind: :analytics, detail: 'Python · exploration'
        consumer :partner_api, 'Partner API', kind: :api, detail: 'scoped data products'
        layer_service :identity, 'Identity provider', kind: :identity,
                      detail: 'SSO · service identities · policy groups', protocol: 'AUTH'
        layer_service :logging, 'Centralized logging', kind: :observability,
                      detail: 'platform events · audit trail · retention', protocol: 'AUTH'

        wire :crm, :object_storage, kind: :ordinary, protocol: 'REST'
        wire :pos_exports, :object_storage, kind: :ordinary, protocol: 'CSV'
        wire :event_stream, :object_storage, kind: :ordinary, protocol: 'EVENTS'
        wire :orchestrator, :object_storage, kind: :trigger
        wire :object_storage, :query_engine, kind: :federated, protocol: 'READ'
        wire :query_engine, :bi_tool, kind: :serve, protocol: 'JDBC'
        wire :query_engine, :notebooks, kind: :serve, protocol: 'KERNEL'
        wire :query_engine, :partner_api, kind: :serve, protocol: 'HTTPS'
      end
    end
  end
end
