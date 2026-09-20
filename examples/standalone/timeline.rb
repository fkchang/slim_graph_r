require 'slim_graph_r'

diagram = SlimGraphR.diagram :timeline, title: 'From intent to interface', style: :ruby, scale: :date do
  event '2026-01-08', 'Say what matters', detail: 'Name the parts and how they connect.'
  event '2026-02-04', 'Let Ruby do the fussy work', emphasis: true, detail: 'Layout and SVG come from code.'
  event '2026-03-21', 'Keep the picture', detail: 'Use the same diagram in a document, app or export.'
end

puts diagram.to_svg if $PROGRAM_NAME == __FILE__
diagram
