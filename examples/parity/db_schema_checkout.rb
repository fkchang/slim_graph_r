# frozen_string_literal: true

require 'slim_graph_r'

module ParityFixtures
  module DBSchemaCheckout
    TABLES = {
      'public.customers' => %w[id email created_at],
      'public.orders' => %w[id customer_id status total placed_at],
      'public.order_items' => %w[id order_id product_id qty unit_price],
      'public.products' => %w[id sku name price +3_more_columns],
      'billing.invoices' => %w[id order_id issued_at]
    }.freeze
    FOREIGN_KEYS = [['orders.customer_id', 'customers.id', :restrict], ['order_items.order_id', 'orders.id', :cascade], ['order_items.product_id', 'products.id', :restrict], ['invoices.order_id', 'orders.id', :restrict]].freeze

    module_function

    def diagram(theme: :light, style: :editorial)

      SlimGraphR.diagram(:db_schema, title: 'Checkout persistence', theme: theme, style: style) do
        table :customers, 'customers', schema: 'public' do
          column :id, 'id', sql_type: 'uuid', constraints: [:pk]
          column :email, 'email', sql_type: 'text', constraints: %i[uq nn]
          column :created_at, 'created_at', sql_type: 'timestamp', constraints: [:nn]
        end
        table :orders, 'orders', schema: 'public' do
          column :id, 'id', sql_type: 'uuid', constraints: [:pk]
          column :customer_id, 'customer_id', sql_type: 'uuid', constraints: %i[fk nn]
          column :status, 'status', sql_type: 'text', constraints: [:nn]
          column :total, 'total', sql_type: 'integer', constraints: [:nn]
          column :placed_at, 'placed_at', sql_type: 'timestamp', constraints: [:nn]
        end
        table :products, 'products', schema: 'public' do
          column :id, 'id', sql_type: 'uuid', constraints: [:pk]
          column :sku, 'sku', sql_type: 'text', constraints: [:uq]
          column :name, 'name', sql_type: 'text', constraints: [:nn]
          column :price, 'price', sql_type: 'integer', constraints: [:nn]
          overflow_columns 3
        end
        table :order_items, 'order_items', schema: 'public' do
          column :id, 'id', sql_type: 'uuid', constraints: [:pk]
          column :order_id, 'order_id', sql_type: 'uuid', constraints: %i[fk nn]
          column :product_id, 'product_id', sql_type: 'uuid', constraints: %i[fk nn]
          column :qty, 'qty', sql_type: 'integer', constraints: [:nn]
          column :unit_price, 'unit_price', sql_type: 'integer', constraints: [:nn]
        end
        table :invoices, 'invoices', schema: 'billing' do
          column :id, 'id', sql_type: 'uuid', constraints: [:pk]
          column :order_id, 'order_id', sql_type: 'uuid', constraints: %i[fk nn]
          column :issued_at, 'issued_at', sql_type: 'timestamp', constraints: [:nn]
        end
        foreign_key :orders, :customer_id, references: %i[customers id], on_delete: :restrict
        foreign_key :order_items, :order_id, references: %i[orders id], on_delete: :cascade
        foreign_key :order_items, :product_id, references: %i[products id], on_delete: :restrict
        foreign_key :invoices, :order_id, references: %i[orders id], on_delete: :restrict
      end
    end
  end
end
