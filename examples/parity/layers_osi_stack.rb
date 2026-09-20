# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module LayersOsiStack
    module_function
    def diagram(**_options)
      raise ArgumentError, 'Layers parity fixture unavailable: pinned example requires unsupported direction indicator and editorial row annotations.'
    end
  end
end
