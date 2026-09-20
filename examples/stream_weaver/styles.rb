# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'
use_layout :wide
header1 'Same intent. Your kind of Ruby.'
text 'Four styles, each with light and dark palettes. The words and relationships stay the same.'

SlimGraphR::Style.names.each do |preset|
  header2 preset.to_s.capitalize
  [:light, :dark].each do |mode|
    diagram :flowchart, title: 'From idea to published', style: preset, theme: mode do
      step :draft
      decision :review, 'Ready?', emphasis: true
      step :publish
      step :revise
      flow :draft, :review
      edge :review, :publish, 'Yes'
      edge :review, :revise, 'Not yet'
    end
  end
end
