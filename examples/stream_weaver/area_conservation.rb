# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'

use_layout :full
header1 'Area and conservation without hidden repair'
text 'Treemap area and Sankey thickness preserve original values, including zero absence, tiny shares, explicit waste, and fractional ribbons.'

diagram :treemap, title: 'Storage · 東京', unit: 'GiB' do
  item :images, 'Images', 80
  item :logs, 'Logs', 19.999, focal: true
  item :trace, 'Trace δ', 0.001
  item :archive, 'Archive', 0
end

diagram :sankey, title: 'CI minutes · conserved', unit: 'minutes', theme: :dark do
  stage :source, 'Input'; stage :work, 'Work'; stage :outcome, 'Outcome'
  node :ci, stage: :source, label: 'CI', value: 100
  node :test, stage: :work, label: 'Test', value: 60
  node :build, stage: :work, label: 'Build', value: 40
  node :passed, stage: :outcome, label: 'Passed', value: 90
  node :waste, stage: :outcome, label: 'Waste', value: 10
  flow :ci, :test, 60; flow :ci, :build, 40
  flow :test, :passed, 55.5; flow :test, :waste, 4.5
  flow :build, :passed, 34.5; flow :build, :waste, 5.5
end
