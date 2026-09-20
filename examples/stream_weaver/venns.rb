# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'

header1 'Named overlap topology'
md 'Bounded partial parity with [Cathryn Lavery’s pinned Diagram Design Venn reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-venn.md).'
text 'Equal circles show which named sets intersect. Their areas do not encode counts, weights, or population.'

%i[light dark].each do |theme|
  diagram :venn, title: "Product fit · #{theme}", style: theme == :light ? :editorial : :ruby, theme: theme do
    set :desirable, 'Desirable'
    set :feasible, 'Feasible'
    set :viable, 'Viable'
    intersection %i[desirable feasible], 'Useful'
    intersection %i[desirable viable], 'Wanted'
    intersection %i[feasible viable], 'Sustainable'
    intersection %i[desirable feasible viable], 'Product fit', focal: true
  end
end
