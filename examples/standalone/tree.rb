# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:tree, title: 'Service ownership') do
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
