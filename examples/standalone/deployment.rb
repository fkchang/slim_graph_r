# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:deployment, title: 'Production placement') do
  zone :edge, 'Edge' do
    cdn :front_door, 'Global CDN', replicas: 2 do
      artifact 'storefront', version: '2026.09.1'
    end
  end
  zone :prod, 'Production / eu-west-1' do
    pod :api, 'API pods', replicas: 3 do
      artifact 'api', version: 'v2.4.1'
      artifact 'otel sidecar', version: '0.109.0'
    end
    managed :primary, 'RDS primary', emphasis: true do
      artifact 'postgres', version: '16.4'
    end
  end
  network :front_door, :api, protocol: 'HTTPS', port: 443
  network :api, :primary, protocol: 'TLS', port: 5432, async: true
end
