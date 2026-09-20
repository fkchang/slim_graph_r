require 'slim_graph_r'

diagram = SlimGraphR.diagram :sequence, title: 'Cache lookup', style: :blueprint do
  participant :client
  participant :service, emphasis: true
  participant :cache, kind: :store
  message :client, :service, 'Fetch document'
  message :service, :cache, 'Find latest version'
  message :cache, :service, 'Cached result', dashed: true
  message :service, :client, 'Return document', dashed: true
end

puts diagram.to_svg if $PROGRAM_NAME == __FILE__
diagram
