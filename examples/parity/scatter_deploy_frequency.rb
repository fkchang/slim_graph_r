# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module ScatterDeployFrequency
    module_function
    def diagram(**options)
      SlimGraphR.diagram(:scatter, title: 'Deploy frequency vs. lead time · 12 teams', x_unit: 'deploys/week', y_unit: 'days', **options) do
        x_scale min: 0, max: 20
        y_scale min: 0, max: 24
        [[2, 20], [4, 18], [4, 16], [6, 14], [8, 12], [8, 10], [10, 8], [12, 6], [12, 10], [16, 4], [20, 2]].each do |x, y|
          anonymous_point x: x, y: y
        end
        point :platform, 'Platform', x: 18, y: 3, focal: true, annotate: true
      end
    end
  end
end
