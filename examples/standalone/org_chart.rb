require 'slim_graph_r'

diagram = SlimGraphR.diagram :org_chart, title: 'A team with clear ownership', style: :mono do
  node :studio, emphasis: true
  node :design
  node :engineering
  node :research
  edge :studio, :design
  edge :studio, :engineering
  edge :design, :research
end

puts diagram.to_svg if $PROGRAM_NAME == __FILE__
diagram
