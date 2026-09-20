# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'

use_layout :full
header1 'Radial values without radial-area claims'
text 'Every radius uses one declared linear zero baseline. Captions state that enclosed area carries no quantity.'

diagram :polar, title: 'Demand by UTC window', unit: '% of peak' do
  scale min: 0, max: 100
  category :night, '00–06', 18
  category :morning, '06–12', 52
  category :midday, '12–18', 100, focal: true
  category :evening, '18–24', 0
end

diagram :radar, title: 'Backend scorecard', unit: 'score / 10', theme: :dark do
  scale min: 0, max: 10
  criterion :latency, 'Latency'
  criterion :recovery, 'Recovery'
  criterion :cost, 'Cost'
  entity :postgres, 'Postgres', values: { latency: 8, recovery: 9, cost: 6 }, focal: true
  entity :sqlite, 'SQLite', values: { latency: 9, recovery: 0, cost: 10 }
end
