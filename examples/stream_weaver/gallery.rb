# streamweaver-doc: v1
# frozen_string_literal: true

require 'slim_graph_r/stream_weaver'

use_theme :doc
use_layout :wide

example = lambda do |type, group, name, use_when, limit, source|
  { type: type, group: group, name: name, use_when: use_when, limit: limit, source: source.freeze }.freeze
end

examples = [
  example.call(:architecture, :systems, 'Architecture',
               'responsibilities and the important paths between them are the question.',
               'Keep it to a legible system slice; dense inventories need several views.', <<~'RUBY'),
    diagram :architecture, title: 'Publishing path' do
      external :reader, 'Reader'
      node :web, 'Web app', emphasis: true
      node :worker, 'Background worker'
      store :database, 'Database'
      flow :reader, :web
      edge :web, :worker, 'Enqueue'
      edge :web, :database, 'Read'
    end
  RUBY
  example.call(:dependency, :systems, 'Dependency graph',
               'you need to show what requires what, including external packages and cycles.',
               'It records declared dependencies, not runtime call frequency or health.', <<~'RUBY'),
    diagram :dependency, title: 'Runtime dependencies' do
      dependency :app, 'App'
      dependency :plugins, 'Plugins'
      dependency :core, 'Core'
      external_dependency :rack, 'Rack', version: '3.2.1', registry: 'RubyGems'
      depends_on :app, :core
      depends_on :plugins, :core
      depends_on :core, :rack
    end
  RUBY
  example.call(:deployment, :systems, 'Deployment',
               'placement, replicas, artifacts, and network boundaries matter together.',
               'This is a declared topology, not a live infrastructure or capacity view.', <<~'RUBY'),
    diagram :deployment, title: 'Production placement' do
      zone :edge, 'Edge' do
        cdn :front_door, 'Global CDN', replicas: 2 do
          artifact 'storefront', version: '2026.09.1'
        end
      end
      zone :prod, 'Production' do
        pod :api, 'API pods', replicas: 3 do
          artifact 'api', version: 'v2.4.1'
        end
        managed :primary, 'Postgres', emphasis: true do
          artifact 'postgres', version: '16.4'
        end
      end
      network :front_door, :api, protocol: 'HTTPS', port: 443
      network :api, :primary, protocol: 'TLS', port: 5432
    end
  RUBY
  example.call(:high_level, :systems, 'High-level platform',
               'a platform overview needs sources, phases, orchestration, and crosscuts.',
               'Use it for orientation; put detailed service behavior in narrower diagrams.', <<~'RUBY'),
    diagram :high_level, title: 'Data platform', cluster: 'Kubernetes' do
      phase :sources, 'Sources' do
        source :postgres, 'PostgreSQL', type: :db
      end
      phase :ingest, 'Ingestion' do
        component :nifi, 'NiFi', role: 'COLL'
      end
      phase :storage, 'Storage' do
        component :minio, 'MinIO', role: 'STORE', focal: true
      end
      connect :postgres, :nifi
      connect :nifi, :minio
      orchestrate :airflow, 'Airflow', targets: %i[nifi minio]
      crosscut :identity, 'Identity', concern: 'Security'
    end
  RUBY
  example.call(:data_flow, :systems, 'Data flow',
               'roles, tools, payloads, and handoffs explain how data moves through work.',
               'It does not prove lineage or data quality; show only relationships you know.', <<~'RUBY'),
    diagram :data_flow, title: 'Reporting pipeline' do
      role :engineers, 'Engineers', key: 'ENG'
      role :analysts, 'Analysts', key: 'ANL'
      step :collect, 'Collect'
      step :prepare, 'Prepare', focal: true
      step :publish, 'Publish'
      transfer :ingest, 'Ingest', role: :engineers, step: :collect, tool: 'SFTP', output: :dataset
      transfer :model, 'Model', role: :analysts, step: :prepare, tool: 'SQL', input: :dataset, output: :table, focal: true
      transfer :query, 'Query', role: :analysts, step: :publish, tool: 'BI', input: :table
      handoff :ingest, :model, kind: :focal, label: 'TRUSTED DATA'
      handoff :model, :query, kind: :publish
    end
  RUBY
  example.call(:dp_integration, :systems, 'Platform integration',
               'a platform boundary with sources, services, and consumers is the subject.',
               'The vocabulary is specific to data platforms and fixed horizontal geometry.', <<~'RUBY'),
    diagram :dp_integration, title: 'Platform surfaces' do
      source :warehouse, 'Warehouse', kind: :database, detail: 'SQL'
      platform 'Data platform' do
        bar :query, 'Query service', role: 'SQL', focal: true, serves: true
        row do
          service :ingest, 'Ingest', role: 'INGEST'
          service :store, 'Object store', role: 'STORE', focal: true
        end
      end
      consumer :reports, 'Reports', kind: :analytics
      wire :warehouse, :query, kind: :federated, protocol: 'JDBC'
      wire :query, :reports, kind: :serve, protocol: 'ODBC'
    end
  RUBY

  example.call(:db_schema, :data, 'Database schema',
               'columns, constraints, indexes, and exact foreign-key rows matter.',
               'This is a selective schema view; it is not generated migration truth.', <<~'RUBY'),
    diagram :db_schema, title: 'Checkout persistence' do
      table :customers, 'customers' do
        column :id, 'id', sql_type: 'uuid', constraints: [:pk]
        column :email, 'email', sql_type: 'text', constraints: %i[uq nn]
      end
      table :orders, 'orders' do
        column :id, 'id', sql_type: 'uuid', constraints: [:pk]
        column :customer_id, 'customer_id', sql_type: 'uuid', constraints: %i[fk nn]
        index 'idx_orders_customer_id'
      end
      foreign_key :orders, :customer_id, references: %i[customers id], on_delete: :restrict
    end
  RUBY
  example.call(:er, :data, 'Entity relationship',
               'domain entities, fields, and relationship cardinalities are the main subject.',
               'Use database schema when physical columns and indexes are the concern.', <<~'RUBY'),
    diagram :er, title: 'Order domain' do
      entity :customer, 'Customer' do
        field :customer_id, 'customer_id', key: :primary, type: 'uuid'
        field :email, 'email', type: 'text'
      end
      entity :order, 'Order', focal: true do
        field :order_id, 'order_id', key: :primary, type: 'uuid'
        field :customer_id, 'customer_id', key: :foreign, type: 'uuid'
      end
      relationship :customer, :order, from: '1', to: '0..*', label: 'places'
    end
  RUBY
  example.call(:uml_class, :data, 'UML class',
               'interfaces, members, inheritance, and realization need explicit notation.',
               'It is a focused class model, not a complete UML tool or code generator.', <<~'RUBY'),
    diagram :uml_class, title: 'Checkout objects' do
      interface :payable, 'Payable' do
        operation '+ authorize(amount: Money): Receipt'
      end
      abstract_class :payment, 'Payment', focal: true do
        attribute '- reference: String'
        operation '+ capture(): Receipt'
      end
      class_type :card_payment, 'CardPayment' do
        attribute '- token: String'
      end
      relation :card_payment, :payment, kind: :inheritance
      relation :card_payment, :payable, kind: :realization
    end
  RUBY
  example.call(:dp_security_matrix, :data, 'Security matrix',
               'access must be stated cell by cell for roles and platform components.',
               'It summarizes intended permissions; it does not inspect or enforce policy.', <<~'RUBY'),
    diagram :dp_security_matrix, title: 'Platform access' do
      role :admins, 'Administrators', code: 'DL-Admins'
      role :readers, 'Readers'
      component :source, 'Source store', hint: 'S3'
      component :reports, 'Published reports', hint: 'BI'
      permission :source, :admins, level: :admin
      permission :source, :readers, level: :deny
      permission :reports, :admins, level: :write
      permission :reports, :readers, level: :read
    end
  RUBY
  example.call(:medallion, :data, 'Medallion tiers',
               'storage tiers and promotion rules explain a curated data lifecycle.',
               'The tiers are declared in order and do not model arbitrary graph topology.', <<~'RUBY'),
    diagram :medallion, title: 'Survey storage tiers' do
      tier :raw, 'Raw', bucket: 'raw-bucket', tool: 'NiFi', format: 'CSV',
           writer: 'Data Engineering', examples: ['source export']
      tier :anon, 'Anonymized', bucket: 'anon-bucket', tool: 'Trino', format: 'Iceberg',
           writer: 'Data Engineering', examples: ['stable household ID'], concern: :security
      tier :aggregate, 'Aggregated', bucket: 'metrics-bucket', tool: 'Trino', format: 'Iceberg',
           writer: 'Data Science', examples: ['employment rate'], focal: true
      promote :raw, :anon, 'REMOVE PII'
      promote :anon, :aggregate, 'AGGREGATE'
    end
  RUBY
  example.call(:it_state, :data, 'IT current state',
               'a before-state landscape needs phases, pain points, handoffs, and crosscuts.',
               'It supports a fixed horizontal current-state story, not future-state planning.', <<~'RUBY'),
    diagram :it_state, title: 'Current IT landscape', subtitle: 'Before the platform' do
      phase :collection, 'Collection' do
        system :survey, 'Survey app', detail: 'PostgreSQL'
      end
      phase :processing, 'Processing' do
        system :drive, 'Shared drive', detail: 'No version control', state: :pain_point
      end
      phase :publication, 'Publication' do
        system :portal, 'Legacy portal', state: :pain_point
      end
      handoff :survey, :drive, 'CSV', style: :link
      handoff :drive, :portal, 'EXCEL', dashed: true
      crosscut :identity, 'Identity', detail: 'LDAP / SSO'
    end
  RUBY

  example.call(:flowchart, :flow, 'Flowchart',
               'steps, decisions, branches, and merges explain a bounded procedure.',
               'Large exception-heavy processes become unreadable; split them by decision.', <<~'RUBY'),
    diagram :flowchart, title: 'Publishing decision' do
      step :draft, 'Prepare draft'
      decision :review, 'Ready to publish?', emphasis: true
      step :publish, 'Publish'
      step :revise, 'Revise'
      flow :draft, :review
      edge :review, :publish, 'Approved'
      edge :review, :revise, 'Needs changes'
    end
  RUBY
  example.call(:process, :flow, 'Process',
               'work needs roles, stages, tools, payloads, handoffs, and feedback.',
               'Use swimlanes for simpler ownership without tool and payload semantics.', <<~'RUBY'),
    diagram :process, title: 'Survey delivery' do
      lane :research, 'Research', key: 'RDE'
      lane :it, 'IT', key: 'IT'
      stage :design, 'Design'
      stage :build, 'Build'
      stage :test, 'Test', focal: true
      operation :draft, 'Draft survey', lane: :research, stage: :design, tool: 'Excel', output: 'FL'
      operation :build_app, 'Build app', lane: :it, stage: :build, tool: 'CSPro', input: 'FL', output: 'TB'
      operation :pilot, 'Pilot test', lane: :research, stage: :test, tool: 'Tablet', input: 'TB', focal: true
      handoff :draft, :build_app
      handoff :build_app, :pilot
    end
  RUBY
  example.call(:swimlane, :flow, 'Swimlane',
               'ownership across lanes and stages matters more than implementation detail.',
               'It shows declared responsibility, not elapsed time or queue size.', <<~'RUBY'),
    diagram :swimlane, title: 'Release ownership' do
      lane :product, 'Product'
      lane :engineering, 'Engineering'
      lane :operations, 'Operations'
      stage :plan, 'Plan'
      stage :build, 'Build'
      stage :ship, 'Ship'
      activity :scope, 'Scope release', lane: :product, stage: :plan
      activity :implement, 'Implement', lane: :engineering, stage: :build
      activity :deploy, 'Deploy', lane: :operations, stage: :ship
      handoff :scope, :implement, focal: true
      handoff :implement, :deploy
    end
  RUBY
  example.call(:state, :flow, 'State machine',
               'valid states and event-driven transitions define a lifecycle.',
               'It models allowed transitions, not the sequence of one observed request.', <<~'RUBY'),
    diagram :state, title: 'Publish lifecycle', direction: :right do
      self.state :draft, 'Draft'
      self.state :review, 'In review'
      self.state :published, 'Published', emphasis: true
      initial :draft
      final :published
      transition :draft, :review, on: 'submit', guard: 'complete?'
      transition :review, :draft, on: 'request changes'
      transition :review, :published, on: 'approve'
    end
  RUBY
  example.call(:sequence, :flow, 'Sequence',
               'message order between participants explains one interaction over time.',
               'It is best for a representative conversation, not every possible branch.', <<~'RUBY'),
    diagram :sequence, title: 'Cache lookup' do
      participant :client, 'Client'
      participant :service, 'Service', emphasis: true
      participant :cache, 'Cache', kind: :store
      message :client, :service, 'Fetch document'
      message :service, :cache, 'Find latest version'
      message :cache, :service, 'Cached result', dashed: true
      message :service, :client, 'Return document', dashed: true
    end
  RUBY
  example.call(:journey, :flow, 'Journey',
               'a persona experience needs stages, sentiment, actions, touchpoints, and pain.',
               'Sentiment is an authored judgment; support it with research outside the diagram.', <<~'RUBY'),
    diagram :journey, title: 'Trial to paid', persona: 'Independent analyst' do
      stage :discover, 'Discover', sentiment: :high do
        action 'Compare plans'
        touchpoint 'Website'
      end
      stage :try, 'Try', sentiment: :medium_high do
        action 'Create a project'
        touchpoint 'App'
      end
      stage :limit, 'Hit the limit', sentiment: :low do
        action 'Upload a second project'
        touchpoint 'App'
        pain 'Usage limit is unclear'
      end
    end
  RUBY
  example.call(:story_map, :flow, 'Story map',
               'activities, user steps, releases, and stories need one planning view.',
               'This is a product-planning cut, not a dependency-aware delivery schedule.', <<~'RUBY'),
    diagram :story_map, title: 'Reporting release', persona: 'Analyst' do
      activity :find, 'Find data' do
        step :search, 'Search catalogue'
        step :filter, 'Filter results'
      end
      activity :share, 'Share it' do
        step :send, 'Send report'
      end
      release :mvp, 'MVP', cut: true do
        story :saved_filter, 'Save filters', activity: :find, ticket: 'RPT-114'
      end
      release :later, 'Later' do
        story :permissions, 'Control access', activity: :share, risk: true
      end
    end
  RUBY
  example.call(:gantt, :flow, 'Gantt',
               'dated tasks, phases, milestones, and review markers form the planning argument.',
               'Dates are authored inputs; the diagram does not calculate critical paths.', <<~'RUBY'),
    diagram :gantt, title: 'Platform launch' do
      phase :foundation, 'Foundation' do
        task :calendar, 'Calendar scale', start: '2026-01-05', finish: '2026-01-16', focal: true
        task :board, 'Board model', start: '2026-01-12', finish: '2026-01-23'
      end
      milestone :cutover, 'Cutover', on: '2026-01-23', phase: :foundation
      marker :review, 'Review', on: '2026-01-16'
    end
  RUBY
  example.call(:kanban, :flow, 'Kanban',
               'current work, WIP limits, ownership, and blocked states need a compact board.',
               'It is a snapshot, not a live tracker; keep the source deliberately current.', <<~'RUBY'),
    diagram :kanban, title: 'Platform work' do
      column :backlog, 'Backlog' do
        card :api, 'API contract'
      end
      column :build, 'In progress', wip_limit: 2 do
        card :cache, 'Cache migration', state: :blocked, focal: true
      end
      column :done, 'Done' do
        card :lint, 'Lint cleanup', owner: 'Nadia', state: :done
      end
    end
  RUBY
  example.call(:timeline, :flow, 'Timeline',
               'a few dated events tell the evolution of a decision, product, or system.',
               'Use Gantt when durations and overlapping work are the important facts.', <<~'RUBY'),
    diagram :timeline, title: 'From intent to interface', scale: :date do
      event '2026-01-08', 'Name the parts'
      event '2026-02-04', 'Give the system a shape', emphasis: true
      event '2026-03-21', 'Keep the result portable'
    end
  RUBY

  example.call(:org_chart, :hierarchy, 'Organization chart',
               'reporting or ownership relationships form a small hierarchy.',
               'Edges communicate structure only; explain dotted-line nuance in prose.', <<~'RUBY'),
    diagram :org_chart, title: 'Design studio' do
      node :studio, 'Studio', emphasis: true
      node :product, 'Product'
      node :engineering, 'Engineering'
      node :research, 'Research'
      edge :studio, :product
      edge :studio, :engineering
      edge :product, :research
    end
  RUBY
  example.call(:tree, :hierarchy, 'Tree',
               'a rooted taxonomy or ownership hierarchy needs nested parent-child branches.',
               'Each item has one parent; use a graph when cross-links carry meaning.', <<~'RUBY'),
    diagram :tree, title: 'Service ownership' do
      root :platform, 'Platform' do
        child :experience, 'Experience' do
          child :web, 'Web'
          child :mobile, 'Mobile'
        end
        child :product, 'Product' do
          child :api, 'API', focal: true
        end
      end
    end
  RUBY
  example.call(:nested, :hierarchy, 'Nested containment',
               'containment itself is the point: scopes inside scopes.',
               'It does not show traffic or dependency direction between contained scopes.', <<~'RUBY'),
    diagram :nested, title: 'Instruction cascade' do
      scope :organization, 'Organization' do
        scope :repository, 'Repository' do
          scope :workspace, 'Workspace' do
            scope :task, 'Task'
          end
        end
      end
    end
  RUBY
  example.call(:layers, :hierarchy, 'Layer stack',
               'ordered conceptual layers explain an abstraction or protocol stack.',
               'Layers are a fixed stack, not nodes with arbitrary lateral dependencies.', <<~'RUBY'),
    diagram :layers, title: 'Network path', axis: 'Abstraction', indicator: :up do
      layer :transport, 'Transport', index: 'L4', detail: 'TCP', focal: true
      layer :network, 'Network', index: 'L3', detail: 'IP'
      layer :link, 'Data link', index: 'L2', detail: 'Ethernet'
      layer :physical, 'Physical', index: 'L1', detail: 'Fiber'
    end
  RUBY
  example.call(:pyramid, :hierarchy, 'Pyramid / funnel',
               'ordered levels or measured conversion stages tell a top-to-bottom story.',
               'Measured funnels need honest from/to counts; the renderer will not infer them.', <<~'RUBY'),
    diagram :pyramid, title: 'Audience qualification', orientation: :funnel,
            mode: :measured, unit: 'accounts' do
      level :reach, 'Reach', from: 12_000, to: 4_800
      level :engage, 'Engage', from: 4_800, to: 1_440
      level :qualify, 'Qualify', from: 1_440, to: 420, focal: true
      level :convert, 'Convert', from: 420, to: 126
    end
  RUBY

  example.call(:quadrant, :strategy, 'Quadrant',
               'two explicit qualitative axes help compare authored judgments.',
               'Coordinates are claims, not measurements, unless you explain the scoring method.', <<~'RUBY'),
    diagram :quadrant, title: 'Platform priorities' do
      horizontal_axis low: 'EASY', high: 'HARD'
      vertical_axis low: 'LOW IMPACT', high: 'HIGH IMPACT'
      item :cache, 'Cache migration', x: 0.72, y: 0.66, focal: true
      item :audit, 'Audit trail', x: -0.58, y: 0.34
      item :cleanup, 'Lint cleanup', x: -0.42, y: -0.46
    end
  RUBY
  example.call(:venn, :strategy, 'Venn',
               'overlap between two or three named sets is the conclusion.',
               'Circle area is not quantitative and only declared intersections are labeled.', <<~'RUBY'),
    diagram :venn, title: 'Product fit' do
      set :desirable, 'Desirable'
      set :feasible, 'Feasible'
      set :viable, 'Viable'
      intersection %i[desirable feasible], 'Useful'
      intersection %i[desirable viable], 'Wanted'
      intersection %i[feasible viable], 'Sustainable'
      intersection %i[desirable feasible viable], 'Product fit', focal: true
    end
  RUBY
  example.call(:loop, :strategy, 'Learning loop',
               'a clockwise cycle and its write-backs explain repeated learning or control.',
               'A loop is not a timeline; it intentionally has no start or duration scale.', <<~'RUBY'),
    diagram :loop, title: 'Self-improving loop', direction: :clockwise do
      hub :memory, 'Shared memory', sublabel: 'one record'
      station :capture, 'Capture'
      station :research, 'Research'
      station :decide, 'Decide', focal: true
      station :act, 'Act'
      station :measure, 'Measure'
      cycle :capture, :research, :decide, :act, :measure
      write_back %i[capture research decide act measure], to: :memory
    end
  RUBY
  example.call(:fishbone, :strategy, 'Fishbone',
               'candidate causes need to be grouped around one clearly stated effect.',
               'It organizes hypotheses; it does not establish causality or rank evidence.', <<~'RUBY'),
    diagram :fishbone, title: 'Latency investigation' do
      effect 'Checkout p99 latency above 2 s'
      category :data, 'Data', side: :above do
        factor 'Missing index'
        factor 'Replica lag'
      end
      category(:deployment, 'Deployment', side: :below) { factor 'Cold workers' }
      category(:observability, 'Observability', side: :above) { factor 'No query breakdown' }
    end
  RUBY
  example.call(:wardley, :strategy, 'Wardley map',
               'a value chain needs visibility, evolution, dependencies, and movement.',
               'Positions are qualitative strategic judgments, not calculated market scores.', <<~'RUBY'),
    diagram :wardley, title: 'Assistant value chain' do
      component :assistant, 'AI assistant', evolution: :genesis, visibility: 0.82
      component :orchestration, 'Agent orchestration', evolution: :custom_built, visibility: 0.58
      component :model_api, 'Model API', evolution: :product, visibility: 0.36, evolving_to: :commodity
      component :compute, 'Compute', evolution: :commodity, visibility: 0.14
      depends_on :assistant, :orchestration
      depends_on :orchestration, :model_api
      depends_on :model_api, :compute
    end
  RUBY

  example.call(:bar, :quantitative, 'Bar chart',
               'discrete categories share one quantitative scale and signed values matter.',
               'Comparisons need one unit and honest bounds; mixed units need separate charts.', <<~'RUBY'),
    diagram :bar, title: 'Net bookings', unit: 'USD millions' do
      scale min: -10, max: 30
      category :north, 'North', 24
      category :south, 'South', -6
      category :online, 'Online', 0, focal: true
    end
  RUBY
  example.call(:line, :quantitative, 'Line chart',
               'ordered values show change over time and explicit gaps must remain visible.',
               'The chart connects declared points only; it does not interpolate missing evidence.', <<~'RUBY'),
    diagram :line, title: 'Incidents', unit: 'incidents/day' do
      x_axis :time, domain: %w[2026-01-01 2026-01-02 2026-01-11 2026-01-21]
      scale min: 0, max: 12
      series :api, 'API', focal: true do
        point 8
        gap reason: 'telemetry outage'
        point 3
        point 5
      end
    end
  RUBY
  example.call(:scatter, :quantitative, 'Scatter plot',
               'two quantities position comparable observations on explicit scales.',
               'Position shows association only; it does not imply a causal relationship.', <<~'RUBY'),
    diagram :scatter, title: 'Latency and errors', x_unit: 'ms', y_unit: '%' do
      x_scale min: -100, max: 600
      y_scale min: -1, max: 8
      point :payments, 'Payments', x: 260, y: 2.8, focal: true, annotate: true
      point :search, 'Search', x: 90, y: 0, annotate: true
      point :cache, 'Cache', x: -40, y: -0.5
    end
  RUBY
  example.call(:treemap, :quantitative, 'Treemap',
               'parts of one whole need areas proportional to a common nonnegative measure.',
               'Small areas are hard to compare precisely; use bars for close values.', <<~'RUBY'),
    diagram :treemap, title: 'Storage allocation', unit: 'GiB' do
      item :images, 'Images', 80
      item :logs, 'Logs', 20, focal: true
      item :archive, 'Archive', 0
    end
  RUBY
  example.call(:sankey, :quantitative, 'Sankey',
               'a conserved quantity flows through stages with explicit residual or waste.',
               'Inputs and outputs must balance; do not use widths for unrelated measures.', <<~'RUBY'),
    diagram :sankey, title: 'CI minutes', unit: 'minutes' do
      stage :source, 'Input'; stage :work, 'Work'; stage :outcome, 'Outcome'
      node :ci, stage: :source, label: 'CI', value: 100
      node :test, stage: :work, label: 'Test', value: 60
      node :build, stage: :work, label: 'Build', value: 40
      node :passed, stage: :outcome, label: 'Passed', value: 90
      node :waste, stage: :outcome, label: 'Waste', value: 10
      flow :ci, :test, 60; flow :ci, :build, 40
      flow :test, :passed, 55; flow :test, :waste, 5
      flow :build, :passed, 35; flow :build, :waste, 5
    end
  RUBY
  example.call(:polar, :quantitative, 'Polar chart',
               'cyclic categories share one radial magnitude scale.',
               'Radius is the only magnitude; sector area and angle are not quantitative.', <<~'RUBY'),
    diagram :polar, title: 'Demand by UTC window', unit: '% of peak' do
      scale min: 0, max: 100
      category :night, '00–06', 18
      category :morning, '06–12', 52
      category :midday, '12–18', 100, focal: true
      category :evening, '18–24', 0
    end
  RUBY
  example.call(:radar, :quantitative, 'Radar chart',
               'a few entities share the same bounded criteria and outline shape aids scanning.',
               'Polygon area has no meaning; compare values along individual axes.', <<~'RUBY'),
    diagram :radar, title: 'Backend scorecard', unit: 'score / 10' do
      scale min: 0, max: 10
      criterion :latency, 'Latency'
      criterion :recovery, 'Recovery'
      criterion :cost, 'Cost'
      entity :postgres, 'Postgres', values: { latency: 8, recovery: 9, cost: 6 }, focal: true
      entity :sqlite, 'SQLite', values: { latency: 9, recovery: 0, cost: 10 }
    end
  RUBY
].freeze

groups = [
  { id: :systems, label: 'Systems & relationships' },
  { id: :data, label: 'Data, structure & access' },
  { id: :flow, label: 'Flow, time & work' },
  { id: :hierarchy, label: 'Hierarchy & composition' },
  { id: :strategy, label: 'Strategy & diagnosis' },
  { id: :quantitative, label: 'Quantitative views' }
].freeze

sidebar_toc sections: groups.map { |group| { id: group.fetch(:id).to_s, label: group.fetch(:label) } }

doc_header(
  eyebrow: 'SlimGraphR · StreamWeaver',
  title: 'Complete diagram atlas',
  pills: [{ text: "#{SlimGraphR::Diagram::TYPES.length} executable examples", variant: :good }, 'Live · Reader · export']
)

md <<~MARKDOWN
  Choose a picture by the question it needs to answer. Every Ruby block below is the exact
  source evaluated to create the diagram beneath it. Copy a block into any StreamWeaver
  document after `require 'slim_graph_r/stream_weaver'`.

  SlimGraphR lays out declared facts. It does not discover architecture, validate evidence,
  or turn qualitative judgments into measurements.
MARKDOWN

groups.each_with_index do |group, group_index|
  doc_section_header format('%02d', group_index + 1), group.fetch(:label), id: group.fetch(:id).to_s

  examples.select { |entry| entry.fetch(:group) == group.fetch(:id) }.each do |entry|
    md <<~MARKDOWN
      ### #{entry.fetch(:name)}

      **Use when:** #{entry.fetch(:use_when)}

      **Limit:** #{entry.fetch(:limit)}
    MARKDOWN
    code_block entry.fetch(:source), lang: 'ruby'
    instance_eval(entry.fetch(:source), "diagram-atlas:#{entry.fetch(:type)}")
  end
end
