require 'slim_graph_r'

diagram = SlimGraphR.diagram :state, title: 'Publish lifecycle', direction: :right, theme: :light, style: :editorial do
  state :draft, 'Draft', detail: 'unpublished'
  state :review, 'In review', detail: 'awaiting approval'
  state :published, 'Published', detail: 'live on site', emphasis: true
  initial :draft
  final :published
  transition :draft, :review, on: 'submit', guard: 'complete?', action: 'queue'
  transition :review, :draft, on: 'request changes'
  transition :review, :review, on: 'recheck', action: 'record audit'
  transition :review, :published, on: 'approve'
end

puts diagram.to_svg if $PROGRAM_NAME == __FILE__
diagram
