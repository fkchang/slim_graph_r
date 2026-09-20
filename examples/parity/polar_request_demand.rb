# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module PolarRequestDemand
    module_function
    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram(:polar, title: 'Request demand by UTC window', unit: '% of daily peak', theme: theme, style: style) do
        scale min: 0, max: 100
        [['00–03',32],['03–06',18],['06–09',24],['09–12',58],['12–15',100],['15–18',82],['18–21',76],['21–24',45]].each_with_index { |(label,value), index| category "utc#{index}", label, value, focal: label == '12–15' }
      end
    end
  end
end
