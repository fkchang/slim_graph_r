# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:pyramid, title: 'Audience qualification', orientation: :funnel, mode: :measured, unit: 'accounts') do
  level :reach, 'Reach', from: 12_000, to: 4_800
  level :engage, 'Engage', from: 4_800, to: 1_440
  level :qualify, 'Qualify', from: 1_440, to: 420, focal: true
  level :convert, 'Convert', from: 420, to: 126
end
