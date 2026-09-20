# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module StoryMapReporting
    module_function
    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram :story_map, title: 'Reporting, first release', persona: 'Reporting analyst', theme: theme, style: style do
        activity(:find, 'Find the data') { step :search, 'Search datasets'; step :preview, 'Preview rows' }
        activity(:build, 'Build the report') { step :columns, 'Pick columns'; step :chart, 'Add a chart' }
        activity(:share, 'Share it') { step :link, 'Send a link' }
        activity(:trust, 'Trust it') { step :freshness, 'Check freshness' }
        release(:mvp, 'MVP', cut: true) do
          story :keyword, 'Keyword search', activity: :find, ticket: 'RPT-101', estimate: '3pt'
          story :table_chart, 'Table + one chart', activity: :build, ticket: 'RPT-102', estimate: '5pt'
          story :public_link, 'Public link', activity: :share, ticket: 'RPT-103', estimate: '2pt'
          story :updated, 'Last-updated stamp', activity: :trust, ticket: 'RPT-104', estimate: '1pt'
        end
        release(:release_2, 'Release 2') do
          story :filters, 'Saved filters', activity: :find, ticket: 'RPT-110', estimate: '3pt'
          story :email, 'Scheduled email', activity: :share, ticket: 'RPT-112', estimate: '5pt'
          story :permissions, 'Row-level permissions', activity: :trust, ticket: 'RPT-114', estimate: '3pt', risk: true
        end
        release(:later, 'Later') do
          story :natural_language, 'Natural-language query', activity: :find, ticket: 'RPT-120', estimate: '8pt'
          story :alerts, 'Alerting on anomalies', activity: :trust, ticket: 'RPT-121', estimate: '5pt'
        end
      end
    end
  end
end
