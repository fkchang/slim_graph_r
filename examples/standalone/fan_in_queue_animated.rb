# frozen_string_literal: true
require 'slim_graph_r'

diagram = SlimGraphR.diagram(:architecture, title: 'Fan-in queue under pressure', style: :ruby, direction: :right) do
  external :web, 'Web app', detail: '7 req/s steady'
  external :erp, 'ERP burst', detail: '20 req/s burst'
  node :queue_open, 'Queue · 2/5', detail: 'Capacity remains'
  node :queue_full, 'Queue · 5/5', detail: 'Capacity reached', emphasis: true
  node :limiter, 'Rate limiter', detail: '19 req/s shed'
  node :worker, 'Worker', detail: '8 req/s service'
  node :stable, 'Controlled equilibrium', detail: 'Worker protected'
  edge :web, :queue_open
  edge :web, :queue_full
  edge :erp, :queue_full
  edge :queue_full, :limiter
  edge :queue_full, :worker
  edge :worker, :stable
end

diagram.storyboard do
  reveal 1, :web, :queue_open, route(:web, :queue_open), 'Steady traffic occupies two of five queue slots'
  reveal 2, :erp, :queue_full, route(:erp, :queue_full), route(:web, :queue_full), 'The burst fills the queue',
    replaces: [:queue_open, route(:web, :queue_open)]
  reveal 3, :limiter, route(:queue_full, :limiter), 'Overflow activates the rate limiter'
  reveal 4, :worker, route(:queue_full, :worker), 'The constrained worker serves eight requests per second'
  reveal 5, :stable, route(:worker, :stable), 'The system reaches a controlled equilibrium'
end
