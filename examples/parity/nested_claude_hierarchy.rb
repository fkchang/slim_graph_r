# frozen_string_literal: true
require 'slim_graph_r'

module ParityFixtures
  module NestedClaudeHierarchy
    module_function
    def diagram(theme: :light, style: :editorial)
      raise ArgumentError, 'Nested CLAUDE.md parity fixture supports only the full-editorial profile' unless style.to_sym == :editorial
      SlimGraphR.diagram :nested, title: 'The CLAUDE.md Hierarchy', theme: theme, style: style do
        scope :global, '~/.claude/ (global)' do
          scope :vault, '~/vault/ (notes)' do
            scope :business, '/business' do
              scope :marketing, '/marketing' do
                scope :project, '/project'
              end
            end
          end
        end
      end
    end
  end
end
