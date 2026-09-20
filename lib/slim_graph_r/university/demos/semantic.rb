# frozen_string_literal: true

require 'tmpdir'
require 'slim_graph_r'

flowchart = SlimGraphR.diagram :flowchart, title: 'Choose with a flowchart', style: :ruby do
  step :draft, 'Draft'
  decision :review, 'Ready?', emphasis: true
  step :publish, 'Publish'
  step :revise, 'Revise'
  flow :draft, :review
  edge :review, :publish, 'Yes'
  edge :review, :revise, 'No'
end

architecture = SlimGraphR.diagram :architecture, title: 'Assign responsibility', style: :editorial do
  external :client, 'Client'
  node :service, 'Review service', emphasis: true
  store :archive, 'Archive'
  flow :client, :service, :archive
end

dependencies = SlimGraphR.diagram :dependency, title: 'Reveal the shared requirement', style: :blueprint, theme: :dark do
  dependency :application
  dependency :cli
  dependency :slim_graph_r
  depends_on :application, :slim_graph_r
  depends_on :cli, :slim_graph_r
end

body = [flowchart, architecture, dependencies].map { |graph| "<section>#{graph.to_svg}</section>" }.join
output = File.join(Dir.tmpdir, 'slim-graph-r-diagram-intent-semantic.html')
File.write(output, "<!doctype html><html><head><meta charset=\"utf-8\"><title>Diagram intent</title></head><body>#{body}</body></html>")
puts output
