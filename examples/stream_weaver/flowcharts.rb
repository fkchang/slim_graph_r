# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'
use_layout :wide
header1 'A flowchart should say what it means'
text 'Real decision shapes, explicit start and finish, and a small junction where branches rejoin. Each label stays clear of its arrow.'
[:light, :dark].each do |mode|
  diagram :flowchart, title: 'A decision, then back together', style: :ruby, theme: mode do
    start :request, 'New request'
    decision :valid, 'Is the request complete?', emphasis: true
    step :process, 'Process the request'
    step :repair, 'Fill in the gaps'
    merge :joined
    finish :done, 'Ready to deliver'
    flow :request, :valid
    edge :valid, :process, 'Yes'
    edge :valid, :repair, 'No'
    flow :process, :joined, :done
    edge :repair, :joined
  end
end
