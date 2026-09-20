# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module LineWeeklySignups
    module_function
    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram(:line, title: 'Weekly signups · Organic leads the growth', unit: 'signups / week', theme: theme, style: style) do
        x_axis :ordinal, domain: %w[W1 W2 W3 W4 W5 W6 W7 W8]; scale min: 0, max: 240
        { organic: [120,135,148,162,155,178,195,210], direct: [80,82,88,90,86,92,95,98], referral: [45,52,48,60,55,68,62,75] }.each { |id, values| series(id, id.to_s.capitalize, focal: id == :organic) { values.each { |value| point value } } }
      end
    end
  end
end
