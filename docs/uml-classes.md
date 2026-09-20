# UML class diagrams

Use `:uml_class` for a bounded static object model where operations or the distinction between inheritance, realization, composition, aggregation, association, and dependency matters. Use ER for conceptual entities and cardinalities without behaviour. Other UML families use their dedicated SlimGraphR types.

## Ruby

This is an ordinary Ruby file. `require 'slim_graph_r'` loads the dependency-free core, the final expression is the diagram, and direct execution writes UTF-8 SVG.

```ruby
# frozen_string_literal: true
require 'slim_graph_r'

DIAGRAM = SlimGraphR.diagram(:uml_class, title: 'Checkout objects · 支払い') do
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

if $PROGRAM_NAME == __FILE__
  File.write(ARGV.fetch(0, 'uml-class.svg'), DIAGRAM.to_svg,
             mode: 'w', encoding: 'UTF-8')
end

DIAGRAM
```

Run it normally with `ruby -Ilib examples/standalone/uml_class.rb uml-class.svg`, or render it through the CLI with `ruby -Ilib exe/slimgraph render examples/standalone/uml_class.rb -o uml-class.svg`.

## Strict JSON

The exact literal Unicode equivalent uses the same class order, member strings, relationship kinds, and endpoints:

```json
{
  "type": "uml_class",
  "title": "Checkout objects · 支払い",
  "classes": [
    {"id":"payable","label":"Payable","kind":"interface","operations":["+ authorize(amount: Money): Receipt"]},
    {"id":"payment","label":"Payment","kind":"abstract_class","focal":true,"attributes":["- reference: String"],"operations":["+ capture(): Receipt"]},
    {"id":"card_payment","label":"CardPayment","kind":"class","attributes":["- token: String"],"operations":["+ authorize(amount: Money): Receipt"]}
  ],
  "relations": [
    {"from":"card_payment","to":"payment","kind":"inheritance"},
    {"from":"card_payment","to":"payable","kind":"realization"}
  ]
}
```

In Ruby, parse JSON as plain data: `SlimGraphR::Document.from_json(File.read('uml_class.json', encoding: 'UTF-8'))` after `require 'slim_graph_r/document'`. The CLI accepts the same file: `ruby -Ilib exe/slimgraph render examples/standalone/uml_class.json -o uml-class.html`.

## Literal model

`class_type`, `abstract_class`, and `interface` create immutable records. Nested `attribute` and `operation` calls each accept one nonblank combined UML member string. SlimGraphR does not parse visibility, names, arguments, types, returns, getters, or setters. Empty attribute or operation compartments are absent.

`relation` accepts exactly `inheritance`, `realization`, `composition`, `aggregation`, `association`, or `dependency`, plus an optional literal `label:`. The label is measured, masked from its route, and rendered only when supplied. Composition and aggregation require `owner:` naming one endpoint; the diamond is placed at that exact owner. Association requires `from_multiplicity:` and `to_multiplicity:` from `1`, `0..*`, or `1..*`; it is a plain undirected line with no arrow. Dependency alone uses an open arrow. Inheritance and realization use hollow triangles at the target, with realization dashed `5,4`; dependency is dashed `4,3`.

## Dimensions and limits

The SVG viewBox uses logical units: class names are 12px, member lines 9px, and stereotypes, multiplicities, and legend labels 8px. The shared readable display scale is 1.5× for UML class diagrams, so those roles render physically at 18px, 13.5px, and 12px. The renderer does not shrink below that floor on narrow screens; the containing document scrolls horizontally.

The bounded slice accepts 2–7 classes, 1–8 relations, at most five attributes and five operations per class, and zero or one focal class. Cards grow only for supplied compartments. Labels that exceed the measured 184–280 logical-pixel card range, more than five relation ports on one card side, or geometry that cannot keep cards, routes, markers, multiplicities, and the complete six-kind legend clear raises `SlimGraphR::LayoutError`. Split the model by package or shorten literal text. Packages/nesting, notes, templates, roles, navigability, n-ary and qualified associations, self-relations, lollipops, code import, arbitrary stereotypes, and the rest of the UML family are deferred.

For StreamWeaver, explicitly load the optional adapter with `require 'slim_graph_r/stream_weaver'`; the same `diagram :uml_class` block then works in live canvas and exported HTML. Core Ruby and the packaged CLI have no StreamWeaver runtime dependency.

This is bounded partial parity with [Cathryn Lavery’s Diagram Design UML class reference at revision `dcd9317ed9ec7477b20005544f36e3313664d815`](https://github.com/cathrynlavery/diagram-design/blob/dcd9317ed9ec7477b20005544f36e3313664d815/skills/diagram-design/references/type-uml-class.md). SlimGraphR is an independent Ruby implementation; the pinned source and upstream MIT notice remain under `vendor/diagram-design`.
