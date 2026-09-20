# frozen_string_literal: true
require 'slim_graph_r'

diagram = SlimGraphR.diagram(:venn, title: 'Product fit · 適合') do
  set :desirable, 'Desirable', subtitle: 'PEOPLE WANT IT'
  set :feasible, 'Feasible'
  set :viable, 'Viable'
  intersection [:desirable, :feasible], 'Useful'
  intersection [:desirable, :viable], 'Wanted'
  intersection [:feasible, :viable], 'Sustainable'
  intersection [:desirable, :feasible, :viable], 'Product fit', focal: true
end

if $PROGRAM_NAME == __FILE__
  File.write(ARGV.fetch(0, 'venn.svg'), diagram.to_svg, mode: 'w', encoding: 'UTF-8')
end

diagram
