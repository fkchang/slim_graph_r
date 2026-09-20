require 'slim_graph_r'

diagram = SlimGraphR.diagram :flowchart, title: 'A decision, then back together', style: :ruby do
  start :request, 'New request'
  decision :valid, 'Is the request complete?', emphasis: true
  step :process, 'Process the request'
  step :repair, 'Fill in the gaps'
  merge :joined
  finish :done, 'Ready to deliver'

  flow :request, :valid
  edge :valid, :process, 'Yes'
  edge :valid, :repair, 'No'
  flow :process, :joined, :done
  edge :repair, :joined
end

puts diagram.to_svg if $PROGRAM_NAME == __FILE__
diagram
