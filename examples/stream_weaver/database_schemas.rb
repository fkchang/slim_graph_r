# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'

header1 'Physical database schemas'
md 'Bounded partial parity with [Cathryn Lavery’s pinned Diagram Design database-schema reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-db-schema.md).'
text 'Every SQL type, constraint, index, foreign-key endpoint, and deletion action is authored explicitly.'

%i[light dark].each do |theme|
  diagram :db_schema, title: "Checkout persistence · #{theme}", style: theme == :light ? :editorial : :ruby, theme: theme do
    table :customers, 'customers', schema: 'public' do
      column :id, 'id', sql_type: 'uuid', constraints: [:pk]
      column :email, 'email', sql_type: 'text', constraints: %i[uq nn]
      index 'uq_customers_email'
    end
    table :orders, 'orders', schema: 'public' do
      column :id, 'id', sql_type: 'uuid', constraints: [:pk]
      column :customer_id, 'customer_id', sql_type: 'uuid', constraints: %i[fk nn]
      column :total_cents, 'total_cents', sql_type: 'integer', constraints: [:nn]
      index 'idx_orders_customer_id'
    end
    foreign_key :orders, :customer_id, references: %i[customers id], on_delete: :restrict
  end
end
