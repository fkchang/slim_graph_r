# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module PyramidConversionFunnel
    module_function
    def diagram(**_options)
      raise ArgumentError, 'Pyramid parity fixture unavailable: pinned example requires unsupported side drop-off annotations and honest funnel counts.'
    end
  end
end
