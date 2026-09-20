# frozen_string_literal: true

require 'slim_graph_r'

module ParityFixtures
  module UMLClassPayments
    CLASSES = {
      'PaymentMethod' => ['+ authorize(amount: Money): AuthResult', '+ capture(ref: String): void'],
      'Card' => ['- number: String', '- expiry: Date', '- cvv: String'],
      'BankTransfer' => ['- iban: String', '- accountHolder: String'],
      'PaymentService' => ['+ charge(order: Order): Receipt'],
      'Order' => ['- id: String', '- placedAt: Date', '- total: Money'],
      'OrderLine' => ['- sku: String', '- qty: Int', '- price: Money'],
      'Customer' => ['- id: String', '- name: String', '- email: String']
    }.freeze
    RELATIONSHIPS = %w[realization realization dependency composition association].freeze

    module_function

    def diagram(theme: :light, style: :editorial)

      SlimGraphR.diagram :uml_class, title: 'Payment relationships', theme: theme, style: style do
        class_type(:payment_service, 'PaymentService') { CLASSES.fetch('PaymentService').each { |value| operation value } }
        interface :payment_method, 'PaymentMethod', focal: true do
          operation '+ authorize(amount: Money): AuthResult'
          operation '+ capture(ref: String): void'
        end
        class_type(:card, 'Card') { CLASSES.fetch('Card').each { |value| attribute value } }
        class_type(:bank_transfer, 'BankTransfer') { CLASSES.fetch('BankTransfer').each { |value| attribute value } }
        class_type(:order, 'Order') { CLASSES.fetch('Order').each { |value| attribute value } }
        class_type(:order_line, 'OrderLine') { CLASSES.fetch('OrderLine').each { |value| attribute value } }
        class_type(:customer, 'Customer') { CLASSES.fetch('Customer').each { |value| attribute value } }

        relation :card, :payment_method, kind: :realization
        relation :bank_transfer, :payment_method, kind: :realization
        relation :payment_service, :payment_method, kind: :dependency, label: 'USES'
        relation :order, :order_line, kind: :composition, owner: :order
        relation :order, :customer, kind: :association, from_multiplicity: '0..*', to_multiplicity: '1'
      end
    end
  end
end
