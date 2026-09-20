require 'slim_graph_r'

diagram = SlimGraphR.diagram :org_chart, title: 'Northstar studio ownership', theme: :light, style: :editorial do
  owner :lead, 'Northstar lead', invoke: '@northstar', scope: 'Direction and release approval', emphasis: true
  owner :intake, 'Intake team', invoke: '#northstar-help', scope: 'Routing and escalation'
  owner :editor, 'Editorial owner', invoke: '@quill', scope: 'Copy and publication', detail: 'Weekday coverage'
  owner :archive, 'Archive owner', scope: 'Long-term records', unavailable: true, detail: 'Setup pending'
  edge :lead, :intake
  edge :lead, :editor
  edge :intake, :archive
  escalation 'Unowned work', to: :intake
  approval 'Production release', by: :lead
  setup_gap 'Archive ownership needs a live invocation route', for: :archive
end

puts diagram.to_svg if $PROGRAM_NAME == __FILE__
diagram
