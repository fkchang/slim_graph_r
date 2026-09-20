# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'
use_layout :wide
header1 'Show the conversation. Keep its meaning.'
text 'Activation bars show who holds control. Frames distinguish alternatives, optional work and repetition. Replies and notifications use different arrowheads.'

cache_flow = proc do
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
[:light, :dark].each do |mode|
  diagram :sequence, title: 'Fetch a document', style: :ruby, theme: mode, &cache_flow
end

diagram :sequence, title: 'A worker earns its keep', style: :blueprint do
  participant :worker, emphasis: true
  participant :queue, kind: :store
  participant :metrics
  loop 'for each queued job' do
    message :worker, :queue, 'Poll for work'
    activate :queue do
      reply :queue, :worker, 'Next job'
    end
    activate :worker do
      message :worker, :worker, 'Process the job'
      activate :worker do
        notify :worker, :metrics, 'Record completion'
      end
    end
  end
  opt 'queue empty' do
    notify :queue, :worker, 'Wait for work'
  end
end
