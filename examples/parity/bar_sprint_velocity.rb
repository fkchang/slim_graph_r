# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module BarSprintVelocity
    module_function
    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram(:bar, title: 'Sprint velocity · 8-sprint view', unit: 'story points', theme: theme, style: style) do
        scale min: 0, max: 120
        [72, 88, 95, 78, 110, 102, 85, 93].each_with_index { |value, index| category "s#{index + 1}", "S#{index + 1}", value, focal: index == 4 }
      end
    end
  end
end
