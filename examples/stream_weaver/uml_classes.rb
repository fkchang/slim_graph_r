# streamweaver-doc: v1
require 'slim_graph_r/stream_weaver'

header1 'UML class models'
md 'Bounded partial parity with [Cathryn Lavery’s pinned Diagram Design UML class reference](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-uml-class.md).'
text 'Members and relationships stay literal. Diamonds, triangles, multiplicities, and dependency arrows appear only when explicitly authored.'

%i[light dark].each do |theme|
  diagram :uml_class, title: "Checkout objects · #{theme}", style: theme == :light ? :editorial : :ruby, theme: theme do
    interface(:payable, 'Payable') { operation '+ authorize(amount: Money): Receipt' }
    abstract_class(:payment, 'Payment', focal: true) { attribute '- reference: String'; operation '+ capture(): Receipt' }
    class_type(:card_payment, 'CardPayment') { attribute '- token: String'; operation '+ authorize(amount: Money): Receipt' }
    relation :card_payment, :payment, kind: :inheritance
    relation :card_payment, :payable, kind: :realization
  end
end
