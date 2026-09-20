# frozen_string_literal: true
require 'slim_graph_r'

module SlimGraphRUMLClass
  DIAGRAM = SlimGraphR.diagram(:uml_class, title: 'Checkout objects') do
    interface :payable, 'Payable' do
      operation '+ authorize(amount: Money): Receipt'
    end
    abstract_class :payment, 'Payment', focal: true do
      attribute '- reference: String'
      operation '+ capture(): Receipt'
    end
    class_type :card_payment, 'CardPayment' do
      attribute '- token: String'
      operation '+ authorize(amount: Money): Receipt'
    end
    relation :card_payment, :payment, kind: :inheritance
    relation :card_payment, :payable, kind: :realization
  end
end

if $PROGRAM_NAME == __FILE__
  output = ARGV.fetch(0, 'uml-class.svg')
  File.write(output, SlimGraphRUMLClass::DIAGRAM.to_svg, mode: 'w', encoding: 'UTF-8')
end

SlimGraphRUMLClass::DIAGRAM
