# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'

header1 'Wardley maps'
md 'Bounded partial parity with [Cathryn Lavery’s pinned Diagram Design Wardley reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-wardley.md).'
text 'Bands and visibility are qualitative author judgments. Links state value-chain dependency; dashed accent arrows alone state explicit movement toward commodity.'

%i[light dark].each do |theme|
  diagram :wardley, title: "Assistant value chain · #{theme}", style: theme == :light ? :editorial : :ruby, theme: theme do
    component :assistant, 'AI assistant', evolution: :genesis, visibility: 0.82
    component :orchestration, 'Agent orchestration', evolution: :custom_built, visibility: 0.58
    component :model_api, 'Model API', evolution: :product, visibility: 0.36, evolving_to: :commodity
    component :compute, 'Compute', evolution: :commodity, visibility: 0.14
    depends_on :assistant, :orchestration
    depends_on :orchestration, :model_api
    depends_on :model_api, :compute
  end
end
