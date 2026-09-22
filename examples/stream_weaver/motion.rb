# frozen_string_literal: true
require 'slim_graph_r/stream_weaver'

diagram(:architecture, title: 'Intent becomes a paved road', style: :ruby, direction: :right) do
  external :developer, 'Developer', detail: 'Signed commit'
  node :build, 'CI build', detail: 'Artifact + provenance'
  decision :gate, 'Policy gate', detail: 'OPA verification', emphasis: true
  node :runtime, 'Isolated runtime', detail: 'Approved deployment'
  store :audit, 'Immutable audit', detail: 'Allowed + blocked'
  flow :developer, :build, :gate, :runtime, :audit
end.storyboard do
  reveal 1, :developer, 'A signed commit enters the paved road'
  reveal 2, :build, route(:developer, :build), 'CI builds the artifact and records provenance'
  reveal 3, :gate, route(:build, :gate), 'The policy gate approves the artifact'
  reveal 4, :runtime, route(:gate, :runtime), 'The approved route enters the isolated runtime'
  reveal 5, :audit, route(:runtime, :audit), 'The immutable audit records the deployment'
end
