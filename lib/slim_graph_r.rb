# frozen_string_literal: true
require_relative 'slim_graph_r/version'
require 'cgi'
require 'securerandom'
require_relative 'slim_graph_r/text'
require_relative 'slim_graph_r/style'
require_relative 'slim_graph_r/motion'
require_relative 'slim_graph_r/motion_player'
require_relative 'slim_graph_r/motion_patterns'
require_relative 'slim_graph_r/quantitative'
require_relative 'slim_graph_r/radial'
require_relative 'slim_graph_r/area_conservation'
require_relative 'slim_graph_r/sequence_definition'
require_relative 'slim_graph_r/diagram'
require_relative 'slim_graph_r/planning_boards'
require_relative 'slim_graph_r/workflow'
require_relative 'slim_graph_r/journey'
require_relative 'slim_graph_r/data_flow'
require_relative 'slim_graph_r/dp_integration'
require_relative 'slim_graph_r/dp_security_matrix'
require_relative 'slim_graph_r/er'
require_relative 'slim_graph_r/db_schema'
require_relative 'slim_graph_r/uml_class'
require_relative 'slim_graph_r/quadrant'
require_relative 'slim_graph_r/venn'
require_relative 'slim_graph_r/loop'
require_relative 'slim_graph_r/fishbone'
require_relative 'slim_graph_r/wardley'
require_relative 'slim_graph_r/layout/graph'
require_relative 'slim_graph_r/layout/dependency'
require_relative 'slim_graph_r/layout/data_flow'
require_relative 'slim_graph_r/layout/dp_integration'
require_relative 'slim_graph_r/layout/dp_security_matrix'
require_relative 'slim_graph_r/layout/er'
require_relative 'slim_graph_r/layout/db_schema'
require_relative 'slim_graph_r/layout/uml_class'
require_relative 'slim_graph_r/layout/quadrant'
require_relative 'slim_graph_r/layout/venn'
require_relative 'slim_graph_r/layout/loop'
require_relative 'slim_graph_r/layout/fishbone'
require_relative 'slim_graph_r/layout/wardley'
require_relative 'slim_graph_r/layout/deployment'
require_relative 'slim_graph_r/layout/high_level'
require_relative 'slim_graph_r/layout/hierarchy'
require_relative 'slim_graph_r/layout/pyramid_medallion'
require_relative 'slim_graph_r/layout/it_state'
require_relative 'slim_graph_r/layout/workflow'
require_relative 'slim_graph_r/layout/planning_boards'
require_relative 'slim_graph_r/layout/journey'
require_relative 'slim_graph_r/layout/editorial'
require_relative 'slim_graph_r/layout/sequence'
require_relative 'slim_graph_r/layout/state'
require_relative 'slim_graph_r/svg'
require_relative 'slim_graph_r/data_flow_svg'
require_relative 'slim_graph_r/dp_integration_svg'
require_relative 'slim_graph_r/dp_security_matrix_svg'
require_relative 'slim_graph_r/er_svg'
require_relative 'slim_graph_r/db_schema_svg'
require_relative 'slim_graph_r/uml_class_svg'
require_relative 'slim_graph_r/quadrant_svg'
require_relative 'slim_graph_r/venn_svg'
require_relative 'slim_graph_r/loop_svg'
require_relative 'slim_graph_r/fishbone_svg'
require_relative 'slim_graph_r/wardley_svg'
require_relative 'slim_graph_r/quantitative_svg'
require_relative 'slim_graph_r/radial_svg'
require_relative 'slim_graph_r/area_conservation_svg'
require_relative 'slim_graph_r/workflow_svg'
require_relative 'slim_graph_r/planning_boards_svg'
require_relative 'slim_graph_r/journey_svg'

module SlimGraphR
  class Error < ArgumentError; end
  class LayoutError < Error; end

  def self.diagram(type = :architecture, **options, &block)
    return Quantitative::Chart.new(type, **options, &block) if %i[bar line scatter].include?(type.to_s.to_sym)
    return Radial::Chart.new(type, **options, &block) if %i[polar radar].include?(type.to_s.to_sym)
    return AreaConservation::Chart.new(type, **options, &block) if %i[treemap sankey].include?(type.to_s.to_sym)
    Diagram.new(type, **options, &block)
  end

  def self.motion_pattern(type, **options)
    Motion::PatternDiagram.new(type, **options).presentation
  end
end
