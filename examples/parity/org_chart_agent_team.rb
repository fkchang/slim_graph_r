# frozen_string_literal: true

require 'slim_graph_r'

module ParityFixtures
  module OrgChartAgentTeam
    module_function

    def diagram(theme: :light, style: :editorial)

      SlimGraphR.diagram :org_chart,
                         title: 'Agent team responsibility map',
                         description: 'A responsibility map for teams, agents, and escalation paths. It makes the front door, owners, invocation paths, and setup gaps visible.',
                         theme: theme,
                         style: style do
        owner :athena, 'Athena', invoke: '@athena', scope: 'route ambiguous work', emphasis: true
        owner :growth, 'Growth', scope: 'ads · analytics'
        owner :content, 'Content', scope: 'email · blog · SEO'
        owner :commerce, 'Commerce', scope: 'shopify · CRO'
        owner :systems, 'Systems', scope: 'agents · runtime'
        owner :media_buyer, 'Media Buyer', invoke: 'Google · Meta', scope: 'paid acquisition'
        owner :maximo, 'Maximo', invoke: 'offers · strategy', scope: 'growth strategy'
        owner :rory, 'Rory', invoke: 'copy · newsletter', scope: 'content publishing'
        owner :porter, 'Porter', invoke: 'Shopify admin', scope: 'commerce operations'
        owner :atlas, 'Atlas', invoke: 'theme · APIs', scope: 'systems integration'
        owner :hermes, 'Hermes', invoke: 'Paperclip health', scope: 'runtime health'

        edge :athena, :growth
        edge :athena, :content
        edge :athena, :commerce
        edge :athena, :systems
        edge :growth, :media_buyer
        edge :growth, :maximo
        edge :content, :rory
        edge :commerce, :porter
        edge :commerce, :atlas
        edge :systems, :hermes

        setup_gap 'Slack bot invitation is still missing', for: :media_buyer
        setup_gap 'Production approval gate needs a named owner', for: :athena
        setup_gap 'Backend name mismatch needs reconciliation', for: :hermes
      end
    end
  end
end
