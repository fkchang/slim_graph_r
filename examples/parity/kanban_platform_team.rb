# frozen_string_literal: true

require 'slim_graph_r'

module ParityFixtures
  module KanbanPlatformTeam
    module_function

    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram :kanban, title: 'Platform team · weekly snapshot',
                         description: 'Platform work by state: a four-card In progress column exceeds its WIP limit and contains the blocked Postgres upgrade.', theme: theme, style: style do
        column :backlog, 'Backlog' do
          card :rate_limiting, 'API rate limiting', ticket: 'AVA-201', owner: 'priya'
          card :terraform_cleanup, 'Terraform module cleanup', ticket: 'AVA-205', owner: 'leo'
          card :onboarding_docs, 'Onboarding docs refresh', ticket: 'AVA-209', owner: 'maya'
        end
        column :in_progress, 'In progress', wip_limit: 3 do
          card :postgres_upgrade, 'Postgres 16 upgrade', ticket: 'AVA-118', owner: 'sam', state: :blocked
          card :node_pool, 'K8s node pool migration', ticket: 'AVA-142', owner: 'priya'
          card :token_rotation, 'Auth token rotation', ticket: 'AVA-150', owner: 'leo'
          card :dashboards, 'Observability dashboards', ticket: 'AVA-161', owner: 'dara'
        end
        column :review, 'Review', wip_limit: 3 do
          card :feature_flags, 'Feature flag cleanup', ticket: 'AVA-176', owner: 'nadia'
          card :vendor_sso, 'Vendor SSO integration', ticket: 'AVA-183', owner: 'sam', state: :waiting
        end
        column :done, 'Done' do
          card :retention, 'Log retention policy', ticket: 'AVA-090', owner: 'leo', state: :done
          card :cache_warmup, 'CI cache warmup', ticket: 'AVA-097', owner: 'maya', state: :done
        end
      end
    end
  end
end
