# frozen_string_literal: true
require 'slim_graph_r/stream_weaver'

diagram :pyramid, title: 'Evidence hierarchy' do
  level :context, 'Context', detail: 'broad signals'
  level :studies, 'Studies', detail: 'repeatable evidence'
  level :synthesis, 'Synthesis', detail: 'reviewed finding', focal: true
  level :decision, 'Decision', detail: 'specific action'
end

diagram :pyramid, title: 'Audience qualification', orientation: :funnel, mode: :measured,
         unit: 'accounts', theme: :dark do
  level :reach, 'Reach', from: 12_000, to: 4_800
  level :engage, 'Engage', from: 4_800, to: 1_440
  level :qualify, 'Qualify', from: 1_440, to: 420, focal: true
  level :convert, 'Convert', from: 420, to: 126
end

diagram :medallion, title: 'Bronze, silver, gold — no archive', style: :blueprint do
  tier :bronze, 'Bronze', bucket: 'landing', tool: 'NiFi', format: 'JSON', writer: 'Data Engineering', examples: ['source records']
  tier :silver, 'Silver', bucket: 'clean', tool: 'Trino', format: 'Iceberg', writer: 'Data Engineering', examples: ['validated rows'], concern: :quality
  tier :gold, 'Gold', bucket: 'products', tool: 'dbt', format: 'Iceberg marts', writer: 'Data Science', examples: ['daily metrics'], focal: true
  promote :bronze, :silver, 'VALIDATE'
  promote :silver, :gold, 'PUBLISH'
end
