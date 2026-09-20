# frozen_string_literal: true
require 'slim_graph_r/stream_weaver'

diagram :deployment, title: 'Production placement · light', style: :editorial, theme: :light do
  zone :edge, 'Edge' do
    cdn :front_door, 'Global CDN', replicas: 2 do
      artifact 'storefront', version: '2026.09.1'
    end
  end
  zone :app, 'Production / eu-west-1' do
    pod :api, 'API pods', replicas: 3 do
      artifact 'api', version: 'v2.4.1'
      artifact 'otel sidecar', version: '0.109.0'
    end
    vm :jobs, 'Job runner' do
      artifact 'worker', version: 'v2.4.1'
    end
  end
  zone :data, 'Private data' do
    managed :primary, 'RDS primary', emphasis: true do
      artifact 'postgres', version: '16.4'
    end
    managed :standby, 'RDS standby' do
      artifact 'postgres', version: '16.4'
    end
  end
  network :front_door, :api, protocol: 'HTTPS', port: 443
  network :api, :jobs, protocol: 'HTTP', port: 9292
  network :api, :primary, protocol: 'TLS', port: 5432
  network :primary, :standby, protocol: 'Postgres', port: 5432, async: true, emphasis: true
end

diagram :deployment, title: 'Recovery placement · dark', style: :ruby, theme: :dark do
  zone :service, 'Private service' do
    pod :web, 'Web pods', replicas: 2 do
      artifact 'web', version: 'v4.8.0'
      artifact 'metrics sidecar', version: '1.12.2'
    end
  end
  zone :recovery, 'Recovery boundary' do
    vm :restore, 'Restore runner' do
      artifact 'restore', version: '2026.09'
    end
  end
  network :restore, :web, protocol: 'SYNC', port: 7443, async: true
end
