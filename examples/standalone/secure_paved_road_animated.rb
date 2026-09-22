# frozen_string_literal: true
require 'slim_graph_r'

diagram = SlimGraphR.diagram(:architecture, title: 'Secure paved road', style: :ruby, direction: :right) do
  external :developer, 'Developer', detail: 'Signed commit'
  node :build, 'CI build', detail: 'Artifact + provenance'
  decision :gate, 'Policy gate', detail: 'OPA verification', emphasis: true
  node :runtime, 'Isolated runtime', detail: 'Approved deployment'
  external :attacker, 'Bypass attempt', detail: 'Blocked at boundary'
  store :audit, 'Immutable audit', detail: 'Allowed + blocked'
  flow :developer, :build, :gate, :runtime, :audit
  edge :attacker, :gate, dashed: true
end

diagram.storyboard do
  reveal 1, :developer, 'A signed commit enters the paved road'
  reveal 2, :build, route(:developer, :build), 'CI builds the artifact and records provenance'
  reveal 3, :gate, :runtime, route(:build, :gate), route(:gate, :runtime), 'The policy gate approves the deployment route'
  reveal 4, :attacker, route(:attacker, :gate), 'A bypass attempt stops at the trust boundary'
  reveal 5, :audit, route(:runtime, :audit), 'The immutable audit records allowed and blocked activity'
end
