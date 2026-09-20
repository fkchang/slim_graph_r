# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module VennProductFit
    SETS = [['Desirable', 'PEOPLE WANT IT'], ['Feasible', 'WE CAN BUILD IT'], ['Viable', 'BUSINESS SUSTAINS']].freeze
    module_function
    def diagram(theme: :light, style: :editorial)

      SlimGraphR.diagram :venn, title: 'Good design · Desirable × Feasible × Viable', theme: theme, style: style do
        set :desirable, SETS[0][0], subtitle: SETS[0][1]
        set :feasible, SETS[1][0], subtitle: SETS[1][1]
        set :viable, SETS[2][0], subtitle: SETS[2][1]
        intersection %i[desirable feasible], 'Prototype'
        intersection %i[desirable viable], 'Vaporware'
        intersection %i[feasible viable], 'Internal tool'
        intersection %i[desirable feasible viable], 'Shippable', focal: true
      end
    end
  end
end
