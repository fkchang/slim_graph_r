# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'
use_layout :wide
header1 'Let the calendar keep its meaning'
text 'Dates keep their exact position. Simultaneous events share a marker. The labels make room for the data.'

history = proc do
  event '2026-04-01', 'Release', detail: 'The public release follows weeks of testing.', emphasis: true
  event '2026-01-01', 'First sketch', detail: 'Start with a description of the parts and their relationships.'
  event '2026-01-16', 'Working renderer', detail: 'The first output makes the design concrete.'
  event '2026-01-16', 'First review', detail: 'A second event on the same day keeps the same position.'
  event '2026-02-01', 'Broader examples', detail: 'Out-of-order input never changes what the calendar says.'
end
[:light, :dark].each do |mode|
  diagram :timeline, title: 'The dates tell the story', style: :ruby, theme: mode, scale: :date, &history
end

diagram :timeline, title: 'An ordered plan', style: :editorial, scale: :ordered do
  event 'Now', 'Describe the parts'
  event 'Next', 'Render the relationships'
  event 'Later', 'Share the result'
end
