# frozen_string_literal: true

require 'tmpdir'
require 'slim_graph_r'

diagram = SlimGraphR.diagram :flowchart, title: 'A draft earns a deliberate review', style: :ruby do
  step :draft, 'Draft the story'
  decision :review, 'Ready to publish?', emphasis: true, detail: 'One intentional choice'
  step :publish, 'Publish the picture'
  step :revise, 'Revise the draft'
  flow :draft, :review
  edge :review, :publish, 'Approved'
  edge :review, :revise, 'Needs work'
end

output = File.join(Dir.tmpdir, 'slim-graph-r-diagram-intent-standalone.html')
File.write(output, diagram.to_html)
puts output
