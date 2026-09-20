# frozen_string_literal: true
require 'slim_graph_r'

SlimGraphR.diagram(
  :it_state,
  title: 'Current IT Landscape',
  subtitle: 'Data pipeline before the platform',
  eyebrow: 'NatStat / Before the platform'
) do
  phase :collection, 'COLLECTION' do
    system :survey, 'Survey Solutions', detail: 'CAPI / PostgreSQL'
    system :registry, 'Civil Registry', detail: 'External / CRVS data', state: :external
  end
  phase :processing, 'PROCESSING' do
    system :drive, 'Shared Drive', detail: 'No version control', state: :pain_point
    system :analysts, 'Analyst Machines', detail: 'SPSS / SAS / Stata / Excel'
  end
  phase :dissemination, 'DISSEMINATION' do
    system :portal, 'Legacy Portal', detail: 'Manual bottleneck', state: :pain_point
    system :website, 'NatStat Website', detail: 'Public / static pages'
  end
  handoff :survey, :drive, 'CSV', style: :link
  handoff :registry, :drive, 'EXCEL', style: :link, dashed: true
  handoff :drive, :analysts, 'COPY', dashed: true
  handoff :analysts, :portal, 'EXCEL', style: :link
  handoff :portal, :website, 'WEB'
  crosscut :identity, 'Identity Manager', detail: 'Active Directory / LDAP / SSO'
end
