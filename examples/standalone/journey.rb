# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:journey, title: 'Trial to paid', persona: 'Independent analyst') do
  stage :discover, 'Discover', sentiment: :high do
    action 'Compare plans'
    touchpoint 'Website'
  end
  stage :try, 'Try', sentiment: :medium_high do
    action 'Create a project'
    touchpoint 'App'
  end
  stage :limit, 'Hit the limit', sentiment: :low do
    action 'Upload a second project'
    touchpoint 'App'
    pain 'Usage limit is unclear'
  end
  stage :upgrade, 'Upgrade', sentiment: :neutral do
    action 'Choose a plan'
    touchpoint 'Checkout'
  end
end
