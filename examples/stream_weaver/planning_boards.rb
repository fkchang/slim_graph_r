# frozen_string_literal: true
require 'slim_graph_r/stream_weaver'

diagram :gantt, title: 'Launch plan' do
  phase :foundation, 'Foundation' do
    task :calendar, 'Calendar scale', start: '2026-01-05', finish: '2026-01-16', focal: true
    task :board, 'Board model', start: '2026-01-12', finish: '2026-01-23'
  end
  milestone :cutover, 'Cutover', on: '2026-01-23', phase: :foundation
  marker :review, 'Review', on: '2026-01-16'
end

diagram :kanban, title: 'Work census', theme: :dark do
  column :backlog, 'Backlog' do
    card :api, 'API contract'
  end
  column :build, 'In progress', wip_limit: 1 do
    card :cache, 'Cache migration', state: :blocked, focal: true
    card :docs, 'Release notes', ticket: 'AVA-216', state: :waiting
  end
  column :done, 'Done' do
    card :lint, 'Lint cleanup', owner: 'nadia', state: :done
  end
end
