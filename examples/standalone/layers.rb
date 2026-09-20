# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(:layers, title: 'Network path', axis: 'Abstraction', indicator: :up) do
  layer :transport, 'Transport', index: 'L4', detail: 'TCP', focal: true
  layer :network, 'Network', index: 'L3', detail: 'IP'
  layer :link, 'Data link', index: 'L2', detail: 'Ethernet'
  layer :physical, 'Physical', index: 'L1', detail: 'Fiber'
end
