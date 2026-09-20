# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:kanban, title: 'Platform work') do
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
