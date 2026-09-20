# frozen_string_literal: true
# encoding: UTF-8
require 'slim_graph_r/stream_weaver'

diagram :fishbone, title: 'Checkout latency investigation · 調査' do
  effect 'Checkout p99 latency above 2 s'
  category(:data, 'Data', side: :above) { factor 'Missing index'; factor 'Replica lag' }
  category(:deployment, 'Deployment', side: :below) { factor 'Cold workers' }
  category(:observability, 'Observability', side: :above) { factor 'No query breakdown' }
end
