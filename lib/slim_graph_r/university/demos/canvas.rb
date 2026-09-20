# streamweaver-doc: v1
# frozen_string_literal: true

require 'slim_graph_r/stream_weaver'

use_theme :doc
header1 'One intention, three durable forms'
text 'The Ruby DSL is the source. The live canvas, Canvas Reader and HTML export all render the same SVG.'

diagram :architecture, title: 'A diagram belongs where the conversation happens', style: :ruby do
  external :author, 'Author', detail: 'Names the intent'
  node :slim_graph_r, 'SlimGraphR', emphasis: true, detail: 'Places the picture'
  node :stream_weaver, 'StreamWeaver', detail: 'Keeps it in view'
  store :export, 'Portable HTML', detail: 'Carries the SVG onward'
  flow :author, :slim_graph_r, :stream_weaver, :export
end
