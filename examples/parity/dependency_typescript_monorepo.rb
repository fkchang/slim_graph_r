# frozen_string_literal: true

require 'slim_graph_r'

module ParityFixtures
  module DependencyTypescriptMonorepo
    module_function

    def diagram(theme: :light, style: :editorial)

      SlimGraphR.diagram :dependency,
                         title: 'TypeScript monorepo dependency graph',
                         description: "Ranked dependency graph of a TypeScript monorepo showing shared-types as the highest fan-in package with four dependents, and one back-edge cycle from utils into shared-types.",
                         theme: theme,
                         style: style do
        dependency :web, 'web'
        dependency :admin, 'admin'
        dependency :api, 'api'
        dependency :ui_kit, 'ui-kit'
        dependency :shared_types, 'shared-types'
        dependency :db, 'db'
        dependency :tokens, 'tokens'
        dependency :utils, 'utils'
        external_dependency :zod, 'zod', version: '3.23', registry: 'npm'

        depends_on :web, :api
        depends_on :web, :ui_kit
        depends_on :admin, :ui_kit
        depends_on :admin, :api
        depends_on :api, :shared_types
        depends_on :api, :db
        depends_on :ui_kit, :shared_types
        depends_on :ui_kit, :tokens
        depends_on :db, :shared_types
        depends_on :shared_types, :utils
        depends_on :shared_types, :zod
        depends_on :utils, :shared_types, cycle: true
      end
    end
  end
end
