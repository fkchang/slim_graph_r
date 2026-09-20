# frozen_string_literal: true
require 'slim_graph_r'

module ParityFixtures
  module HighLevelDataStack
    module_function
    def diagram(theme: :light, style: :editorial)
      raise ArgumentError, 'High-level data-stack parity fixture unavailable: pinned composition requires unsupported icon catalog, vertical concern chevrons, and source-to-component semantics.'
    end
  end
end
