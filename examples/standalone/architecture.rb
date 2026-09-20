require 'slim_graph_r'

diagram = SlimGraphR.diagram :architecture, title: 'Express intention. Get the picture.', style: :ruby do
  external :intent, 'Your intent', detail: 'Parts and relationships'
  node :ruby, 'A little Ruby', emphasis: true, detail: 'Layout, labels and connectors'
  node :svg, 'A clear diagram', detail: 'Portable SVG'
  flow :intent, :ruby, :svg
end

puts diagram.to_svg if $PROGRAM_NAME == __FILE__
diagram
