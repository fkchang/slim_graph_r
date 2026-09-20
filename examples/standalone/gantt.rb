# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:gantt, title: '0.15 plan') do
  phase :foundation, 'Foundation' do
    task :calendar, 'Calendar scale', start: '2026-01-05', finish: '2026-01-16', focal: true
    task :board, 'Board model', start: '2026-01-12', finish: '2026-01-23'
  end
  milestone :cutover, 'Cutover', on: '2026-01-23', phase: :foundation
  marker :review, 'Review', on: '2026-01-16'
end
