# frozen_string_literal: true

require 'slim_graph_r'

module ParityFixtures
  module ProcessSurveyBuild
    module_function

    def diagram(theme: :light, style: :editorial)
      SlimGraphR.diagram :process, title: 'Order fulfillment across four teams',
                         description: 'An order moves through customer, support, warehouse, and finance ownership from placement to close.', theme: theme, style: style do
        lane :customer, 'Customer', key: 'CUS'
        lane :support, 'Support', key: 'SUP'
        lane :warehouse, 'Warehouse', key: 'WHS'
        lane :finance, 'Finance', key: 'FIN'
        stage :order, 'Order'
        stage :verify, 'Verify'
        stage :allocate, 'Allocate', focal: true
        stage :pick, 'Pick'
        stage :pack, 'Pack'
        stage :pay, 'Pay'
        stage :receive, 'Receive'
        stage :close, 'Close'
        operation :place_order, 'Place order', lane: :customer, stage: :order, tool: 'storefront', detail: 'cart → order', output: 'DB'
        operation :verify_order, 'Verify order', lane: :support, stage: :verify, tool: 'service desk', detail: 'order → cleared', input: 'DB', output: 'DB'
        operation :allocate_stock, 'Allocate stock', lane: :warehouse, stage: :allocate, tool: 'inventory system', detail: 'order → pick list', input: 'DB', output: 'LS', focal: true
        operation :pick_items, 'Pick items', lane: :warehouse, stage: :pick, tool: 'handheld scanner', detail: 'list → picked', input: 'LS', output: 'LS'
        operation :pack_order, 'Pack order', lane: :warehouse, stage: :pack, tool: 'packing station', detail: 'picked → shipment', input: 'LS', output: 'FL'
        operation :capture_payment, 'Capture payment', lane: :finance, stage: :pay, tool: 'payment gateway', detail: 'shipment → receipt', input: 'FL', output: 'TB'
        operation :receive_shipment, 'Receive shipment', lane: :customer, stage: :receive, tool: 'delivery portal', detail: 'receipt → confirmed', input: 'TB', output: 'WB'
        operation :close_order, 'Close order', lane: :support, stage: :close, tool: 'service desk', detail: 'confirmed → closed', input: 'WB'
        handoff :place_order, :verify_order
        handoff :verify_order, :allocate_stock
        handoff :allocate_stock, :pick_items
        handoff :pick_items, :pack_order
        handoff :pack_order, :capture_payment
        handoff :capture_payment, :receive_shipment
        handoff :receive_shipment, :close_order
      end
    end
  end
end
