# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module DPSecurityMatrixPlatform
    module_function
    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram :dp_security_matrix, title: 'Data platform access matrix', theme: theme, style: style do
        role :engineer, 'Data Engineer', code: 'GRP-DATA-ENG'
        role :scientist, 'Data Scientist', code: 'GRP-DATA-SCI'
        role :analyst, 'Analyst', code: 'GRP-ANALYST'
        role :administrator, 'Administrator', code: 'GRP-ADMIN'
        role :partner, 'External Partner', code: 'GRP-PARTNER'

        component :storage, 'Object storage', hint: 'S3'
        component :query, 'Query engine', hint: 'SQL'
        component :notebooks, 'Notebooks', hint: 'PY'
        component :bi, 'BI tool', hint: 'DASH'
        component :orchestrator, 'Orchestrator', hint: 'DAG'

        matrix = {
          storage:      %i[write read deny admin deny],
          query:        %i[write read read admin read],
          notebooks:    %i[write write deny admin deny],
          bi:           %i[write read write admin read],
          orchestrator: %i[write read deny admin deny]
        }
        roles = %i[engineer scientist analyst administrator partner]
        matrix.each do |component_id, levels|
          roles.zip(levels).each do |role_id, level|
            options = { level: level }
            if component_id == :bi && role_id == :partner
              permission component_id, role_id, 'Read', **options, note: 'shared dashboards', focal: true
            else
              label = { write: 'Write', read: 'Read', deny: 'None', admin: 'Admin' }.fetch(level)
              permission component_id, role_id, label, **options
            end
          end
        end
      end
    end
  end
end
