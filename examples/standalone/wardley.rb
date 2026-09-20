# frozen_string_literal: true
require 'slim_graph_r'

module SlimGraphRWardley
  DIAGRAM = SlimGraphR.diagram(:wardley, title: 'Assistant value chain') do
    component :assistant, 'AI assistant', evolution: :genesis, visibility: 0.82
    component :orchestration, 'Agent orchestration', evolution: :custom_built, visibility: 0.58
    component :model_api, 'Model API', evolution: :product, visibility: 0.36, evolving_to: :commodity
    component :compute, 'Compute', evolution: :commodity, visibility: 0.14
    depends_on :assistant, :orchestration
    depends_on :orchestration, :model_api
    depends_on :model_api, :compute
  end
end

if $PROGRAM_NAME == __FILE__
  File.write(ARGV.fetch(0, 'wardley.svg'), SlimGraphRWardley::DIAGRAM.to_svg,
             mode: 'w', encoding: 'UTF-8')
end

SlimGraphRWardley::DIAGRAM
