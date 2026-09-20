# frozen_string_literal: true
require 'slim_graph_r/stream_weaver'

diagram :swimlane, title: 'Survey delivery — ownership' do
  lane :research, 'Research'
  lane :it, 'IT'
  lane :field, 'Field services'
  stage :design, 'Design'
  stage :build, 'Build'
  stage :test, 'Test'
  activity :draft, 'Draft survey', lane: :research, stage: :design
  activity :build_app, 'Build app', lane: :it, stage: :build
  activity :pilot, 'Pilot test', lane: :field, stage: :test
  handoff :draft, :build_app, focal: true
  handoff :build_app, :pilot
end

diagram :process, title: 'Quarterly survey — tools and payloads', theme: :dark do
  lane :research, 'Research', key: 'RDE'
  lane :it, 'IT', key: 'IT'
  lane :field, 'Field services', key: 'FLD'
  stage :design, 'Design'
  stage :build, 'Build'
  stage :test, 'Test', focal: true
  operation :draft, 'Draft survey', lane: :research, stage: :design, tool: 'Excel', output: 'FL'
  operation :build_app, 'Build app', lane: :it, stage: :build, tool: 'CSPro', detail: 'form + validation', input: 'FL', output: 'TB'
  operation :pilot, 'Pilot test', lane: :field, stage: :test, tool: 'Tablet', input: 'TB', focal: true
  handoff :draft, :build_app
  handoff :build_app, :pilot
  trigger :pilot, :build_app, 'RETEST'
end
