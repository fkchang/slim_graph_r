# frozen_string_literal: true
require 'slim_graph_r/stream_weaver'

header1 'Entity relationships'
md 'Bounded partial parity with [Cathryn Lavery’s pinned Diagram Design ER reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-er.md).'
text 'Relationships and both endpoint cardinalities are authored explicitly. Field names never infer physical foreign keys.'

%i[light dark].each do |theme|
  diagram :er, title: "Order domain · #{theme}", style: theme == :light ? :editorial : :ruby, theme: theme do
    entity(:customer, 'Customer') { field :customer_id, 'customer_id', key: :primary; field :email, 'email' }
    entity(:order, 'Order', focal: true) do
      field :order_id, 'order_id', key: :primary
      field :customer_id, 'customer_id', key: :foreign
      field :placed_at, 'placed_at'
    end
    relationship :customer, :order, from: '1', to: '0..*', label: 'places'
  end
end
