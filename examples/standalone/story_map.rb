# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:story_map, title: 'Reporting first release', persona: 'Analyst') do
  activity :find, 'Find the data' do
    step :search, 'Search catalogue'
    step :filter, 'Filter results'
  end
  activity :build, 'Build the report' do
    step :chart, 'Create chart'
  end
  activity :share, 'Share it' do
    step :send, 'Send report'
  end
  release :mvp, '2026-09-30', cut: true do
    story :saved_filter, 'Save filters', activity: :find, ticket: 'RPT-114', estimate: '3pt'
    story :templates, 'Use templates', activity: :build
  end
  release :later, 'Later' do
    story :permissions, 'Control report access', activity: :share, risk: true
  end
end
