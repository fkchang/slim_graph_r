# frozen_string_literal: true
require 'slim_graph_r'

module SlimGraphREntityRelationships
  DIAGRAM = SlimGraphR.diagram(:er, title: 'Order domain · 注文') do
    entity :customer, 'Customer' do
      field :customer_id, 'customer_id', key: :primary, type: 'uuid'
      field :email, 'email', type: 'text', qualifier: 'unique'
    end
    entity :order, 'Order', kind: :aggregate_root, focal: true do
      field :order_id, 'order_id', key: :primary, type: 'uuid'
      field :customer_id, 'customer_id', key: :foreign, type: 'uuid'
      field :placed_at, 'placed_at', type: 'timestamp'
    end
    relationship :customer, :order, from: '1', to: '0..*', label: 'places'
  end
end

if $PROGRAM_NAME == __FILE__
  output = ARGV.fetch(0, 'entity-relationships.svg')
  File.write(output, SlimGraphREntityRelationships::DIAGRAM.to_svg, mode: 'w', encoding: 'UTF-8')
end

SlimGraphREntityRelationships::DIAGRAM
