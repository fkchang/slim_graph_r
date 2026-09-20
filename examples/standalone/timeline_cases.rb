require 'slim_graph_r'

diagram = SlimGraphR.diagram :timeline, title: 'The dates tell the story', style: :ruby, scale: :date do
  event '2026-04-01', 'Release', detail: 'The public release follows weeks of testing.', emphasis: true
  event '2026-01-01', 'First sketch', detail: 'Start with a description of the parts and their relationships.'
  event '2026-01-16', 'Working renderer', detail: 'The first output makes the design concrete.'
  event '2026-01-16', 'First review', detail: 'A second event on the same day keeps the same position.'
  event '2026-02-01', 'Broader examples', detail: 'Out-of-order input never changes what the calendar says.'
end

puts diagram.to_svg if $PROGRAM_NAME == __FILE__
diagram
