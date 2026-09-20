# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module TreemapWorldPopulation
    module_function
    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram(:treemap, title: 'World population · six continents', unit: 'billions', theme: theme, style: style) do
        [['Asia',4.78],['Africa',1.48],['Europe',0.75],['North America',0.61],['South America',0.43],['Oceania',0.05]].each { |label,value| item label.downcase.gsub(' ', '_'), label, value, focal: label == 'Asia' }
      end
    end
  end
end
