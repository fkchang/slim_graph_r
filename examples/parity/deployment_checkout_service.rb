# frozen_string_literal: true

require 'slim_graph_r'

module ParityFixtures
  module DeploymentCheckoutService
    module_function

    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram :deployment,
                         title: 'Checkout service, production',
                         description: 'Deployment diagram placing the checkout service across an edge CDN zone, a production Kubernetes zone running ingress and API pods, and a data zone with a primary Postgres instance replicating to a standby.',
                         theme: theme,
                         style: style do
        zone :edge, 'Edge' do
          cdn :cloudflare, 'Cloudflare' do
            artifact 'edge-cache', version: 'v1.2'
          end
        end
        zone :prod, 'Prod / eu-west-1' do
          pod :ingress, 'ingress' do
            artifact 'nginx-ingress', version: 'v1.11'
          end
          pod :app, 'app', replicas: 3 do
            artifact 'checkout-api', version: 'v2.4.1'
            artifact 'sidecar-otel', version: 'v0.9'
          end
        end
        zone :data, 'Data' do
          managed :rds_primary, 'rds-primary', emphasis: true do
            artifact 'postgres', version: '16.2'
          end
          managed :rds_standby, 'rds-standby' do
            artifact 'postgres', version: '16.2'
          end
        end

        network :cloudflare, :ingress, protocol: 'HTTPS', port: 443
        network :ingress, :app, protocol: 'HTTP', port: 8080
        network :app, :rds_primary, protocol: 'TLS', port: 5432
        network :rds_primary, :rds_standby, protocol: 'WAL STREAM', port: 5432, async: true, emphasis: true
      end
    end
  end
end
