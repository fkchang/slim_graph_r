# frozen_string_literal: true
require 'slim_graph_r'
module ParityFixtures
  module WardleyAIValueChain
    module_function
    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram(:wardley, title: 'AI value chain', theme: theme, style: style) do
        component :answer, 'Answer in the flow of work', evolution: :genesis, visibility: 0.86
        component :chat, 'Chat UI', evolution: :custom_built, visibility: 0.72
        component :orchestration, 'Agent orchestration', evolution: :custom_built, visibility: 0.58, evolving_to: :product
        component :evals, 'Eval harness', evolution: :custom_built, visibility: 0.43
        component :vector, 'Vector store', evolution: :product, visibility: 0.31
        component :llm, 'LLM API', evolution: :product, visibility: 0.25, evolving_to: :commodity
        component :gpu, 'GPU compute', evolution: :commodity, visibility: 0.14
        component :object_storage, 'Object storage', evolution: :commodity, visibility: 0.08
        depends_on :answer, :chat; depends_on :chat, :orchestration; depends_on :orchestration, :evals; depends_on :orchestration, :vector; depends_on :evals, :llm; depends_on :vector, :object_storage; depends_on :llm, :gpu
      end
    end
  end
end
