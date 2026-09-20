# frozen_string_literal: true
require 'slim_graph_r/stream_weaver'

diagram :journey, title: 'Trial path', persona: 'Independent analyst' do
  stage(:discover, 'Discover', sentiment: :high) { action 'Compare plans'; touchpoint 'Website' }
  stage(:try, 'Try', sentiment: :medium_high) { action 'Create a project'; touchpoint 'App' }
  stage(:limit, 'Hit the limit', sentiment: :low) do
    action 'Upload a second project'
    touchpoint 'App'
    pain 'Usage limit is unclear'
  end
  stage(:upgrade, 'Upgrade', sentiment: :neutral) { action 'Choose a plan'; touchpoint 'Checkout' }
end

diagram :story_map, title: 'Report scope', persona: 'Analyst', theme: :dark, style: :ruby do
  activity(:find, 'Find the data') { step :search, 'Search catalogue'; step :filter, 'Filter results' }
  activity(:build, 'Build the report') { step :chart, 'Create chart' }
  activity(:share, 'Share it') { step :send, 'Send report' }
  release :mvp, '2026-09-30', cut: true do
    story :saved_filter, 'Save filters', activity: :find, ticket: 'RPT-114', estimate: '3pt'
    story :templates, 'Use templates', activity: :build
  end
  release(:later, 'Later') { story :permissions, 'Control report access', activity: :share, risk: true }
end
