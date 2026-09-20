# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'

use_layout :wide
header1 'Ownership at a glance'
text 'Names, invocation routes, responsibilities, coverage gaps, and operating rules stay distinct.'

diagram :org_chart, title: 'Northstar studio · light', theme: :light do
  owner :lead, 'Northstar lead', invoke: '@northstar', scope: 'Direction and release approval', emphasis: true
  owner :intake, 'Intake team', invoke: '#northstar-help', scope: 'Routing and escalation'
  owner :editor, 'Editorial owner', invoke: '@quill', scope: 'Copy and publication'
  owner :archive, 'Archive owner', scope: 'Long-term records', unavailable: true
  edge :lead, :intake
  edge :lead, :editor
  edge :intake, :archive
  escalation 'Unowned work', to: :intake
  approval 'Production release', by: :lead
end

diagram :org_chart, title: 'Lantern workshop · dark', theme: :dark, style: :ruby do
  owner :lead, 'Lantern lead', invoke: '@lantern', scope: 'Direction and approvals', emphasis: true
  owner :team, 'Request team', invoke: '#lantern-desk', scope: 'Intake and routing'
  owner :maker, 'Workshop owner', invoke: '@maker', scope: 'Build and delivery'
  owner :night, 'Night owner', scope: 'After-hours coverage', unavailable: true, detail: 'Setup needed'
  edge :lead, :team
  edge :lead, :maker
  edge :team, :night
  escalation 'After-hours request', to: :team
  approval 'Public delivery', by: :lead
end
