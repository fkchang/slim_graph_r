# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:nested, title: 'Instruction cascade') do
  scope :organization, 'Organization' do
    scope :repository, 'Repository' do
      scope :workspace, 'Workspace' do
        scope :task, 'Task'
      end
    end
  end
end
