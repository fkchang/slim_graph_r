# frozen_string_literal: true
require 'slim_graph_r'

module SlimGraphRDatabaseSchema
  DIAGRAM = SlimGraphR.diagram(:db_schema, title: 'Checkout persistence · 注文') do
    table :customers, 'customers', schema: 'public' do
      column :id, 'id', sql_type: 'uuid', constraints: [:pk]
      column :email, 'email', sql_type: 'text', constraints: %i[uq nn]
      index 'uq_customers_email'
    end

    table :orders, 'orders', schema: 'public' do
      column :id, 'id', sql_type: 'uuid', constraints: [:pk]
      column :customer_id, 'customer_id', sql_type: 'uuid', constraints: %i[fk nn]
      column :total_cents, 'total_cents', sql_type: 'integer', constraints: [:nn]
      overflow_columns 2
      index 'idx_orders_customer_id'
    end

    foreign_key :orders, :customer_id,
                references: %i[customers id], on_delete: :restrict
  end
end

if $PROGRAM_NAME == __FILE__
  output = ARGV.fetch(0, 'database-schema.svg')
  File.write(output, SlimGraphRDatabaseSchema::DIAGRAM.to_svg, mode: 'w', encoding: 'UTF-8')
end

SlimGraphRDatabaseSchema::DIAGRAM
