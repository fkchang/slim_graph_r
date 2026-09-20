# frozen_string_literal: true
require 'slim_graph_r'

module ParityFixtures
  module ItStateNorthwind
    module_function
    def diagram(theme: :light, style: :editorial)
      raise ArgumentError, 'IT state Northwind parity fixture unavailable: pinned composition requires unsupported icons, per-component colors, and complete footer semantics.'
    end
  end
end
