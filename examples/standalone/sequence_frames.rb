require 'slim_graph_r'

diagram = SlimGraphR.diagram :sequence, title: 'Fetch a document', style: :ruby do
  participant :client
  participant :api, 'API', emphasis: true
  participant :store, 'Document store', kind: :store

  message :client, :api, 'Fetch document'
  activate :api do
    alt do
      branch 'cached' do
        reply :api, :client, 'Cached document'
      end
      branch 'not cached' do
        message :api, :store, 'Read document'
        activate :store do
          reply :store, :api, 'Document'
        end
        reply :api, :client, 'Document'
      end
    end
  end
end

puts diagram.to_svg if $PROGRAM_NAME == __FILE__
diagram
