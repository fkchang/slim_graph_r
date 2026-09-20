# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module FishboneCheckoutLatency
    CATEGORIES = { 'DEPLOY' => ['canary skipped', 'config drift'], 'DATA' => ['index missing on orders.created_at', 'table 3x forecast'], 'RUNTIME' => ['connection pool cap 20', 'GC pauses'], 'OBSERVABILITY' => ['no p99 alert', 'dashboard sampled at 5m'], 'PEOPLE' => ['on-call handover mid-incident'] }.freeze
    module_function
    def diagram(**options)
      SlimGraphR.diagram(:fishbone, title: 'Checkout p99 latency · Root-cause fishbone', **options) do
        effect 'Checkout p99 latency 4x for 90 minutes'
        category(:deploy, 'DEPLOY', side: :above) { factor 'canary skipped'; factor 'config drift' }
        category(:data, 'DATA', side: :below, confirmed: true) { factor 'index missing on orders.created_at'; factor 'table 3x forecast' }
        category(:runtime, 'RUNTIME', side: :above) { factor 'connection pool cap 20'; factor 'GC pauses' }
        category(:observability, 'OBSERVABILITY', side: :below) { factor 'no p99 alert'; factor 'dashboard sampled at 5m' }
        category(:people, 'PEOPLE', side: :above) { factor 'on-call handover mid-incident' }
      end
    end
  end
end
