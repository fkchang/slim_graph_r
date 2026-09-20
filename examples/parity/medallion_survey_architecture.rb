# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module MedallionSurveyArchitecture
    module_function
    def diagram(**_options)
      raise ArgumentError, 'Medallion parity fixture unavailable: pinned example requires unsupported field cards, wrapped values, and promotion path semantics.'
    end
  end
end
