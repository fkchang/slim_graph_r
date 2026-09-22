# Data and structure

**Supported:** `:db_schema`, `:er`, `:uml_class`, `:dp_security_matrix`, `:medallion`, `:it_state`

| Reader must understand | Use | Avoid when |
|---|---|---|
| Domain entities, conceptual fields, and authored cardinality | `:er` | SQL types, indexes, and row-level foreign keys are the claim. |
| Physical tables, columns, constraints, indexes, and foreign keys | `:db_schema` | The model is conceptual or incomplete. |
| Classes/interfaces, literal members, inheritance, realization, or ownership | `:uml_class` | Runtime calls or package dependencies are the subject. |
| Explicit permission for every role × component cell | `:dp_security_matrix` | Permissions are unknown or inferred; every cell must be authored. |
| Ordered storage tiers and adjacent promotions | `:medallion` | Storage is not tiered or promotions skip arbitrary nodes. |
| A legacy/current-state landscape arranged by phase with pain points | `:it_state` | The figure is a future-state architecture or live health view. |

## Evidence gate

Do not infer a relationship from matching field names. Do not turn an omitted permission into denial. A selective schema view must say what it omits; it is not migration truth.

## Smallest useful pattern

```ruby
SlimGraphR.diagram :er, title: 'Order domain' do
  entity(:customer, 'Customer') { field :id, 'id', key: :primary, type: 'uuid' }
  entity(:order, 'Order') { field :customer_id, 'customer_id', key: :foreign, type: 'uuid' }
  relationship :customer, :order, from: '1', to: '0..*', label: 'places'
end
```

Read `docs/entity-relationships.md`, `docs/database-schemas.md`, `docs/uml-classes.md`, `docs/access-matrices.md`, `docs/medallions.md`, and `docs/it-current-state.md`.
