require 'slim_graph_r'

publishing = SlimGraphR.diagram :flowchart, title: 'From draft to published', style: :ruby do
  step :draft
  decision :review, 'Ready to publish?', emphasis: true
  step :publish
  step :revise
  flow :draft, :review
  edge :review, :publish, 'Approved'
  edge :review, :revise, 'Needs changes'
end

puts publishing.to_svg if $PROGRAM_NAME == __FILE__
publishing
