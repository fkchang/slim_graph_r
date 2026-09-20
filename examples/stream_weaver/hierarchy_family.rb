# frozen_string_literal: true
require 'slim_graph_r/stream_weaver'

diagram :tree, title: 'Service ownership' do
  root :platform, 'Platform', detail: 'Shared foundation' do
    child :experience, 'Experience' do
      child :web, 'Web'
      child :mobile, 'Mobile'
    end
    child :product, 'Product' do
      child :api, 'API', focal: true
      child :jobs, 'Background jobs'
    end
    child :operations, 'Operations'
  end
end

diagram :nested, title: 'Instruction cascade', style: :blueprint, theme: :dark do
  scope :organization, 'Organization' do
    scope :repository, 'Repository' do
      scope :workspace, 'Workspace' do
        scope :task, 'Task'
      end
    end
  end
end

diagram :layers, title: 'Network path', axis: 'Abstraction', indicator: :up, style: :ruby do
  layer :transport, 'Transport', index: 'L4', detail: 'TCP', focal: true
  layer :network, 'Network', index: 'L3', detail: 'IP'
  layer :link, 'Data link', index: 'L2', detail: 'Ethernet'
  layer :physical, 'Physical', index: 'L1', detail: 'Fiber'
end
