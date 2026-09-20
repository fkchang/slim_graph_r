SlimGraphR.diagram :flowchart, title: 'Publishing' do
  step :draft
  decision :review, 'Ready?', emphasis: true
  step :publish
  step :revise
  flow :draft, :review
  edge :review, :publish, 'Yes'
  edge :review, :revise, 'No'
end
