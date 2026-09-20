# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'

header1 'Quadrant decisions'
md 'Bounded partial parity with [Cathryn Lavery’s pinned Diagram Design quadrant reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-quadrant.md).'
text 'Every point is an authored qualitative judgment. The renderer preserves its position and fails when a label cannot remain clear in that quadrant.'

%i[light dark].each do |theme|
  diagram :quadrant, title: "Platform priorities · #{theme}", style: theme == :light ? :editorial : :ruby, theme: theme do
    horizontal_axis low: 'EASY', high: 'HARD'
    vertical_axis low: 'LOW IMPACT', high: 'HIGH IMPACT'
    item :cache, 'Cache migration', x: 0.72, y: 0.66, focal: true
    item :audit, 'Audit trail', x: -0.58, y: 0.34
    item :cleanup, 'Lint cleanup', x: -0.42, y: -0.46
    item :docs, 'Documentation', x: 0.35, y: -0.62
  end
end
