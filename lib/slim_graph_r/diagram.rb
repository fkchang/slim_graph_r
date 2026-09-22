# frozen_string_literal: true
module SlimGraphR
  Artifact = Struct.new(:name, :version, keyword_init: true)
  DeploymentZone = Struct.new(:id, :label, keyword_init: true)
  ItStatePhase = Struct.new(:id, :label, keyword_init: true)
  HighLevelPhase = Struct.new(:id, :label, :columns, keyword_init: true)
  HighLevelSource = Struct.new(:id, :label, :detail, :source_type, :phase, keyword_init: true)
  HighLevelComponent = Struct.new(:id, :label, :detail, :role, :phase, :focal, keyword_init: true)
  HighLevelConnection = Struct.new(:from, :to, keyword_init: true)
  HighLevelOrchestration = Struct.new(:id, :label, :detail, :concern, :targets, keyword_init: true)
  TreeNode = Struct.new(:id, :label, :detail, :focal, :parent_id, :depth, keyword_init: true)
  ContainmentScope = Struct.new(:id, :label, :parent_id, :depth, keyword_init: true)
  LayerBand = Struct.new(:id, :label, :index, :detail, :focal, keyword_init: true)
  PyramidLevel = Struct.new(:id, :label, :detail, :from, :to, :focal, keyword_init: true)
  MedallionTier = Struct.new(:id, :label, :bucket, :tool, :format, :writer, :examples, :focal, :archive, :concern, keyword_init: true)
  MedallionPromotion = Struct.new(:from, :to, :label, keyword_init: true)
  MedallionWritePath = Struct.new(:id, :tag, :title, :detail, :concern, keyword_init: true)
  Crosscut = Struct.new(:id, :label, :detail, :concern, keyword_init: true)
  Node = Struct.new(:id, :label, :detail, :emphasis, :kind, :group, :invoke, :scope, :unavailable, :version, :registry,
                    :zone, :replicas, :artifacts, keyword_init: true)
  Edge = Struct.new(:from, :to, :label, :dashed, :kind, :cycle, :protocol, :port, :emphasis, keyword_init: true)
  Group = Struct.new(:id, :label, keyword_init: true)
  Event = Struct.new(:date, :label, :detail, :emphasis, keyword_init: true)
  OrgRule = Struct.new(:kind, :label, :owner, keyword_init: true)
  OrgSetupGap = Struct.new(:label, :owner, keyword_init: true)
  State = Struct.new(:id, :label, :detail, :emphasis, keyword_init: true)
  Transition = Struct.new(:from, :to, :on, :guard, :action, keyword_init: true) do
    def label
      "#{on}#{guard ? " [#{guard}]" : ''}#{action ? " / #{action}" : ''}"
    end
  end

  class Diagram
    MESSAGE_KINDS = %i[call return async success].freeze
    NODE_KINDS = %i[service store external decision start finish merge].freeze
    TYPES = %i[architecture bar data_flow db_schema uml_class quadrant venn loop fishbone wardley dependency deployment dp_integration dp_security_matrix er flowchart gantt high_level it_state journey kanban layers line medallion nested org_chart polar process pyramid radar sankey scatter sequence state story_map swimlane timeline tree treemap].freeze
    INFRASTRUCTURE_KINDS = %i[host vm pod managed cdn].freeze
    IT_SYSTEM_STATES = %i[standard external pain_point].freeze
    HANDOFF_STYLES = %i[neutral link accent].freeze
    HIGH_LEVEL_SOURCE_TYPES = %i[db ftp web legacy api].freeze
    HIGH_LEVEL_RESERVED_CONCERNS = %w[orchestration security observability governance backup].freeze
    PYRAMID_ORIENTATIONS = %i[pyramid funnel].freeze
    PYRAMID_MODES = %i[hierarchy measured].freeze
    MEDALLION_CONCERNS = %i[security quality product analysis].freeze
    ORG_OPTION_UNSET = Object.new.freeze
    IT_OPTION_UNSET = Object.new.freeze
    HIGH_LEVEL_OPTION_UNSET = Object.new.freeze
    FAMILY_OPTION_UNSET = Object.new.freeze
    attr_reader :type, :title, :description, :direction, :theme, :style, :scale, :nodes, :edges, :groups, :events, :rules,
                :states, :transitions, :initial_state, :final_states, :zones, :phases, :crosscuts, :subtitle, :eyebrow, :setup_gaps,
                :cluster, :sources, :components, :connections, :orchestration,
                :tree_nodes, :containment_scopes, :layers, :axis, :indicator,
                :orientation, :mode, :unit, :levels, :tiers, :promotions, :write_paths, :persona
    attr_reader :workflow_lanes, :workflow_stages, :activities, :operations, :workflow_handoffs, :workflow_trigger
    attr_reader :gantt_phases, :gantt_tasks, :gantt_milestones, :gantt_markers, :kanban_columns
    attr_reader :journey_stages, :story_activities, :story_releases

    def initialize(type, title: 'Diagram', description: nil, direction: nil, theme: :light, style: :editorial, scale: :auto,
                   subtitle: IT_OPTION_UNSET, eyebrow: IT_OPTION_UNSET, cluster: HIGH_LEVEL_OPTION_UNSET,
                   axis: FAMILY_OPTION_UNSET, indicator: FAMILY_OPTION_UNSET,
                   orientation: FAMILY_OPTION_UNSET, mode: FAMILY_OPTION_UNSET, unit: FAMILY_OPTION_UNSET,
                   persona: FAMILY_OPTION_UNSET, &block)
      @type = type.to_sym
      raise Error, "Unsupported diagram type: #{type}. Use Mermaid for other types." unless TYPES.include?(@type)
      if @type != :it_state && [subtitle, eyebrow].any? { |value| !value.equal?(IT_OPTION_UNSET) }
        raise Error, 'subtitle and eyebrow are available only in an IT current-state diagram'
      end
      if @type != :high_level && !cluster.equal?(HIGH_LEVEL_OPTION_UNSET)
        raise Error, 'cluster is available only in a high-level diagram'
      end
      if @type != :layers && !axis.equal?(FAMILY_OPTION_UNSET)
        raise Error, 'axis is available only in a layer-stack diagram'
      end
      if @type != :layers && !indicator.equal?(FAMILY_OPTION_UNSET)
        raise Error, 'indicator is available only in a layer-stack diagram'
      end
      if @type != :pyramid && !orientation.equal?(FAMILY_OPTION_UNSET)
        raise Error, 'orientation is available only in a pyramid diagram'
      end
      if @type != :pyramid && !mode.equal?(FAMILY_OPTION_UNSET)
        raise Error, 'mode is available only in a pyramid diagram'
      end
      if @type != :pyramid && !unit.equal?(FAMILY_OPTION_UNSET)
        raise Error, 'unit is available only in a pyramid diagram'
      end
      if !%i[journey story_map].include?(@type) && !persona.equal?(FAMILY_OPTION_UNSET)
        raise Error, 'persona is available only in journey and story-map diagrams'
      end
      if %i[pyramid medallion].include?(@type) && !direction.nil?
        raise Error, "#{@type == :pyramid ? 'Pyramid' : 'Medallion'} diagrams do not accept direction; use #{ @type == :pyramid ? 'orientation' : 'declaration order' }"
      end
      raise Error, 'Loop direction is required and must be :clockwise' if @type == :loop && direction.nil?
      raise Error, 'Fishbone diagrams use fixed horizontal geometry and do not accept direction' if @type == :fishbone && !direction.nil?
      raise Error, 'Wardley maps use fixed qualitative axes and do not accept direction' if @type == :wardley && !direction.nil?
      @direction = direction || (%i[architecture data_flow deployment dp_integration high_level it_state medallion process state swimlane].include?(@type) ? :right : :down)
      if @type == :loop
        raise Error, 'Loop direction must be :clockwise' unless @direction == :clockwise
      else
        raise Error, 'Direction must be :right or :down' unless %i[right down].include?(@direction)
      end
      raise Error, 'Dependency diagrams use fixed :down direction' if @type == :dependency && @direction != :down
      raise Error, 'Data-flow diagrams use fixed :right direction' if @type == :data_flow && @direction != :right
      raise Error, 'DP integration diagrams use fixed :right direction' if @type == :dp_integration && @direction != :right
      raise Error, 'DP security matrices use fixed :down direction' if @type == :dp_security_matrix && @direction != :down
      raise Error, 'ER diagrams use fixed :down direction' if @type == :er && @direction != :down
      raise Error, 'Database-schema diagrams use fixed :down direction' if @type == :db_schema && @direction != :down
      raise Error, 'UML class diagrams use fixed :down direction' if @type == :uml_class && @direction != :down
      raise Error, 'Deployment diagrams use fixed :right direction' if @type == :deployment && @direction != :right
      raise Error, 'High-level diagrams use fixed :right direction' if @type == :high_level && @direction != :right
      raise Error, 'IT current-state diagrams support only horizontal direction: :right' if @type == :it_state && @direction != :right
      if %i[layers nested].include?(@type) && @direction != :down
        raise Error, "#{@type == :layers ? 'Layer-stack' : 'Nested-containment'} diagrams use fixed :down direction"
      end
      @style = Style.fetch(style).name
      @scale = validated_scale(scale)
      @theme = theme.to_sym
      raise Error, 'Theme must be :light, :dark, or :auto' unless %i[light dark auto].include?(@theme)
      @title, @description = Text.clean(title), description && Text.clean(description)
      @subtitle = clean_it_heading(subtitle, 'subtitle')
      @eyebrow = clean_it_heading(eyebrow, 'eyebrow')
      @cluster = @type == :high_level ? clean_high_level_cluster(cluster) : nil
      @axis = @type == :layers ? clean_layer_axis(axis) : nil
      @indicator = @type == :layers ? clean_layer_indicator(indicator) : nil
      @orientation = @type == :pyramid ? clean_pyramid_enum(orientation, :pyramid, PYRAMID_ORIENTATIONS, 'orientation') : nil
      @mode = @type == :pyramid ? clean_pyramid_enum(mode, :hierarchy, PYRAMID_MODES, 'mode') : nil
      @unit = @type == :pyramid ? clean_pyramid_unit(unit) : nil
      @persona = if %i[journey story_map].include?(@type)
        clean = persona.equal?(FAMILY_OPTION_UNSET) ? '' : Text.clean(persona)
        raise Error, 'Journey and story-map persona is required and must not be blank' if clean.strip.empty?
        clean
      end
      @nodes, @edges, @groups, @events, @rules, @setup_gaps, @zones = [], [], [], [], [], [], []
      @phases, @crosscuts = [], []
      @sources, @components, @connections, @orchestration = [], [], [], nil
      @tree_nodes, @containment_scopes, @layers = [], [], []
      @levels, @tiers, @promotions, @write_paths = [], [], [], []
      @gantt_phases, @gantt_tasks, @gantt_milestones, @gantt_markers, @kanban_columns = [], [], [], [], []
      @journey_stages, @story_activities, @story_releases = [], [], []
      @workflow_lanes, @workflow_stages, @activities, @operations, @workflow_handoffs, @workflow_trigger = [], [], [], [], [], nil
      @states, @transitions, @final_states, @initial_count = [], [], [], 0
      @sequence = SequenceDefinition.new if @type == :sequence
      instance_eval(&block) if block
      validate!
      @sequence&.finish!(@nodes)
      @nodes.each { |node| node.artifacts&.each(&:freeze); node.artifacts&.freeze }
      @orchestration&.targets&.freeze
      @orchestration&.freeze
      [@nodes, @edges, @groups, @events, @rules, @setup_gaps, @states, @transitions, @final_states, @zones, @phases, @crosscuts,
       @sources, @components, @connections, @tree_nodes, @containment_scopes, @layers,
       @levels, @tiers, @promotions, @write_paths,
       @gantt_phases, @gantt_tasks, @gantt_milestones, @gantt_markers].each do |list|
        list.each(&:freeze)
        list.freeze
      end
      @kanban_columns.each do |column|
        column.cards.each(&:freeze)
        column.cards.freeze
        column.freeze
      end
      @kanban_columns.freeze
      @journey_stages.each do |item|
        item.pains.each(&:freeze)
        item.pains.freeze
        item.freeze
      end
      @journey_stages.freeze
      @story_activities.each do |item|
        item.steps.each(&:freeze)
        item.steps.freeze
        item.freeze
      end
      @story_activities.freeze
      @story_releases.each do |item|
        item.stories.each(&:freeze)
        item.stories.freeze
        item.freeze
      end
      @story_releases.freeze
      [@workflow_lanes, @workflow_stages, @activities, @operations, @workflow_handoffs].each do |list|
        list.each(&:freeze)
        list.freeze
      end
      @workflow_trigger&.freeze
      freeze
    end

    def level(id, label = nil, detail: nil, from: FAMILY_OPTION_UNSET, to: FAMILY_OPTION_UNSET, focal: false)
      raise Error, 'level is available only in a pyramid diagram' unless type == :pyramid
      raise Error, 'focal must be true or false' unless [true, false].include?(focal)
      clean_id, clean_label = family_identity(id, label, 'Pyramid level')
      raise Error, 'Pyramid level labels must be at most 28 characters' if clean_label.length > 28
      clean_detail = detail && Text.clean(detail)
      raise Error, 'Pyramid level detail must not be blank when supplied' if clean_detail&.strip&.empty?
      raise Error, 'Pyramid level details must be at most 38 characters' if clean_detail&.length.to_i > 38
      if mode == :hierarchy
        unless from.equal?(FAMILY_OPTION_UNSET) && to.equal?(FAMILY_OPTION_UNSET)
          raise Error, 'Hierarchy pyramid levels do not accept from or to quantities'
        end
        from = to = nil
      else
        raise Error, 'Measured pyramid levels require from and to quantities' if from.equal?(FAMILY_OPTION_UNSET) || to.equal?(FAMILY_OPTION_UNSET)
        validate_pyramid_number!(from, 'from')
        validate_pyramid_number!(to, 'to')
      end
      @levels << PyramidLevel.new(id: clean_id, label: clean_label, detail: clean_detail, from: from, to: to, focal: focal)
    end

    def tier(id, label = nil, bucket:, tool:, format:, writer:, examples:, focal: false, archive: false, concern: nil)
      raise Error, 'tier is available only in a medallion diagram' unless type == :medallion
      raise Error, 'focal must be true or false' unless [true, false].include?(focal)
      raise Error, 'archive must be true or false' unless [true, false].include?(archive)
      clean_id, clean_label = family_identity(id, label, 'Medallion tier')
      fields = { bucket: bucket, tool: tool, format: format, writer: writer }.transform_values do |value|
        value.nil? ? '' : Text.clean(value)
      end
      fields.each { |key, value| raise Error, "Tier #{key} must not be blank" if value.strip.empty? }
      raise Error, 'Tier examples must contain one or two nonblank strings' unless examples.is_a?(Array) && examples.size.between?(1, 2)
      clean_examples = examples.map do |value|
        raise Error, 'Tier examples must contain one or two nonblank strings' unless value.is_a?(String)
        clean = Text.clean(value)
        raise Error, 'Tier examples must contain one or two nonblank strings' if clean.strip.empty?
        clean
      end.freeze
      clean_concern = clean_medallion_concern(concern)
      @tiers << MedallionTier.new(id: clean_id, label: clean_label, **fields, examples: clean_examples,
                                  focal: focal, archive: archive, concern: clean_concern)
    end

    def promote(from, to, label)
      raise Error, 'promote is available only in a medallion diagram' unless type == :medallion
      clean_label = Text.clean(label)
      raise Error, 'Promotion label must not be blank' if clean_label.strip.empty?
      raise Error, 'Promotion labels must be uppercase and at most 14 characters' unless clean_label == clean_label.upcase && clean_label.length <= 14
      @promotions << MedallionPromotion.new(from: Text.clean(from), to: Text.clean(to), label: clean_label)
    end

    def write_path(id, tag:, title:, detail:, concern: nil)
      raise Error, 'write_path is available only in a medallion diagram' unless type == :medallion
      clean_id = Text.clean(id)
      fields = { tag: tag, title: title, detail: detail }.transform_values { |value| value.nil? ? '' : Text.clean(value) }
      raise Error, 'Write-path ID must not be blank' if clean_id.strip.empty?
      fields.each { |key, value| raise Error, "Write-path #{key} must not be blank" if value.strip.empty? }
      @write_paths << MedallionWritePath.new(id: clean_id, **fields, concern: clean_medallion_concern(concern))
    end

    def root(id, label = nil, detail: nil, focal: false, &block)
      raise Error, 'root is available only in a tree diagram' unless type == :tree
      raise Error, 'Tree roots cannot be nested; use child' if @current_tree_parent
      append_tree_node(id, label, detail: detail, focal: focal, parent_id: nil, depth: 1, &block)
    end

    def child(id, label = nil, detail: nil, focal: false, &block)
      raise Error, 'child is available only in a tree diagram' unless type == :tree
      raise Error, 'A tree child must be declared inside a root or child block' unless @current_tree_parent
      append_tree_node(id, label, detail: detail, focal: focal, parent_id: @current_tree_parent.id,
                       depth: @current_tree_parent.depth + 1, &block)
    end

    def scope(id, label = nil, &block)
      raise Error, 'scope is available only in a nested-containment diagram' unless type == :nested
      depth = @current_containment_scope ? @current_containment_scope.depth + 1 : 1
      raise Error, 'Nested-containment diagrams allow at most five levels' if depth > 5
      clean_id, clean_label = family_identity(id, label, 'Containment scope')
      item = ContainmentScope.new(
        id: clean_id, label: clean_label, parent_id: @current_containment_scope&.id, depth: depth
      )
      @containment_scopes << item
      previous = @current_containment_scope
      @current_containment_scope = item
      instance_eval(&block) if block
      item
    ensure
      @current_containment_scope = previous
    end

    def layer(id, label = nil, index:, detail: nil, focal: false)
      raise Error, 'layer is available only in a layer-stack diagram' unless type == :layers
      raise Error, 'focal must be true or false' unless [true, false].include?(focal)
      clean_id, clean_label = family_identity(id, label, 'Layer')
      clean_index = Text.clean(index)
      raise Error, 'Layer index must not be blank' if clean_index.strip.empty?
      clean_detail = detail && Text.clean(detail)
      raise Error, 'Layer detail must not be blank when supplied' if clean_detail&.strip&.empty?
      @layers << LayerBand.new(id: clean_id, label: clean_label, index: clean_index, detail: clean_detail, focal: focal)
    end

    def state(id, label = nil, detail: nil, emphasis: false)
      raise Error, 'state is available only in a state machine' unless type == :state
      clean_id = Text.clean(id)
      clean_label = Text.clean(label || id.to_s.tr('_', ' ').sub(/\A./, &:upcase))
      raise Error, 'State labels must not be blank' if clean_label.strip.empty?
      clean_detail = detail.nil? ? nil : Text.clean(detail)
      raise Error, 'State detail must not be blank when supplied' if clean_detail&.strip&.empty?
      @states << State.new(id: clean_id, label: clean_label, detail: clean_detail, emphasis: !!emphasis)
    end

    def initial(id)
      raise Error, 'initial is available only in a state machine' unless type == :state
      @initial_count += 1
      @initial_state = Text.clean(id)
    end

    def final(id)
      raise Error, 'final is available only in a state machine' unless type == :state
      @final_states << Text.clean(id)
    end

    def transition(from, to, on:, guard: nil, action: nil)
      raise Error, 'transition is available only in a state machine' unless type == :state
      event = Text.clean(on)
      raise Error, 'Transition event must not be blank' if event.strip.empty?
      cleaned_guard = clean_transition_part(guard, 'guard')
      cleaned_action = clean_transition_part(action, 'action')
      @transitions << Transition.new(
        from: Text.clean(from), to: Text.clean(to), on: event, guard: cleaned_guard, action: cleaned_action
      )
    end

    def node(id, label = nil, detail: nil, emphasis: false, kind: :service,
             invoke: ORG_OPTION_UNSET, scope: ORG_OPTION_UNSET, unavailable: ORG_OPTION_UNSET)
      raise Error, 'Dependency diagrams use dependency or external_dependency, not node' if type == :dependency
      raise Error, 'Deployment diagrams use host, vm, pod, managed, or cdn inside a zone, not node' if type == :deployment
      raise Error, 'A state machine uses state, not node' if type == :state
      raise Error, 'IT current-state diagrams use system inside a phase, not node' if type == :it_state
      raise Error, 'High-level diagrams use component inside a phase, not node' if type == :high_level
      raise Error, 'Tree diagrams use root and child, not node' if type == :tree
      raise Error, 'Nested-containment diagrams use scope, not node' if type == :nested
      raise Error, 'Layer-stack diagrams use layer, not node' if type == :layers
      raise Error, "#{type.to_s.capitalize} diagrams use their dedicated planning-board DSL, not node" if %i[gantt kanban].include?(type)
      raise Error, 'Declare participants at sequence top level' if @sequence&.nested?
      raise Error, 'Timeline diagrams use event, not node' if type == :timeline
      org_options = [invoke, scope, unavailable]
      if type != :org_chart && org_options.any? { |value| !value.equal?(ORG_OPTION_UNSET) }
        raise Error, 'invoke, scope, and unavailable are valid only in an org chart'
      end
      if !unavailable.equal?(ORG_OPTION_UNSET) && ![true, false].include?(unavailable)
        raise Error, 'unavailable must be true or false'
      end
      raise Error, "Node kind must be one of #{NODE_KINDS.join(', ')}" unless NODE_KINDS.include?(kind)
      if %i[start finish merge].include?(kind) && type != :flowchart
        raise Error, "#{kind} nodes belong in a flowchart"
      end
      raise Error, 'Merge points do not take detail text or emphasis' if kind == :merge && (detail || emphasis)
      @nodes << Node.new(
        id: Text.clean(id), label: Text.clean(label || id.to_s.tr('_', ' ').sub(/\A./, &:upcase)),
        detail: detail && Text.clean(detail), emphasis: !!emphasis, kind: kind, group: @current_group,
        invoke: clean_org_text(invoke), scope: clean_org_text(scope),
        unavailable: unavailable.equal?(ORG_OPTION_UNSET) ? false : !!unavailable
      )
    end
    alias participant node
    alias step node

    def dependency(id, label = nil)
      raise Error, 'dependency is available only in a dependency diagram' unless type == :dependency
      append_dependency(id, label, kind: :service)
    end

    def external_dependency(id, label = nil, version:, registry:)
      raise Error, 'external_dependency is available only in a dependency diagram' unless type == :dependency
      raise Error, 'External dependency version must not be blank' if version.nil? || Text.clean(version).strip.empty?
      raise Error, 'External dependency registry must not be blank' if registry.nil? || Text.clean(registry).strip.empty?
      append_dependency(id, label, kind: :external, version: version, registry: registry)
    end

    def decision(id, label = nil, **options) = node(id, label, **options, kind: :decision)
    def start(id, label = nil, **options) = node(id, label, **options, kind: :start)
    def finish(id, label = nil, **options) = node(id, label, **options, kind: :finish)
    def merge(id) = node(id, kind: :merge)
    def store(id, label = nil, **options) = node(id, label, **options, kind: :store)
    def external(id, label = nil, **options) = node(id, label, **options, kind: :external)

    def owner(id, name = nil, invoke: nil, scope: nil, unavailable: false, **options)
      raise Error, 'owner is available only in an org chart' unless type == :org_chart
      raise Error, 'Owner name must not be blank' if name && Text.clean(name).strip.empty?
      node(id, name, invoke: invoke, scope: scope, unavailable: unavailable, **options)
    end

    def escalation(label, to:)
      org_rule(:escalation, label, to)
    end

    def approval(label, by:)
      org_rule(:approval, label, by)
    end

    def setup_gap(label, for:)
      raise Error, 'setup_gap is available only in an org chart' unless type == :org_chart
      clean_label = Text.clean(label)
      raise Error, 'Setup-gap text must not be blank' if clean_label.strip.empty?
      owner_id = Text.clean(binding.local_variable_get(:for))
      raise Error, 'Setup-gap owner must not be blank' if owner_id.strip.empty?
      @setup_gaps << OrgSetupGap.new(label: clean_label, owner: owner_id)
    end

    def flow(*ids)
      raise Error, 'A state machine uses transition, not flow' if type == :state
      raise Error, 'A flow needs at least two node IDs' if ids.size < 2
      ids.each_cons(2) { |from, to| edge(from, to) }
    end

    def edge(from, to, annotation = nil, label: annotation, dashed: nil, kind: nil)
      raise Error, 'Dependency diagrams use depends_on, not edge' if type == :dependency
      raise Error, 'Deployment diagrams use network with protocol and port, not edge' if type == :deployment
      raise Error, 'A state machine uses transition, not edge' if type == :state
      raise Error, 'IT current-state diagrams use handoff, not edge' if type == :it_state
      raise Error, 'High-level diagrams use connect, not edge' if type == :high_level
      raise Error, 'Tree structure comes from nested root and child blocks, not edge' if type == :tree
      raise Error, 'Nested-containment diagrams do not accept edges' if type == :nested
      raise Error, 'Layer-stack diagrams do not accept edges' if type == :layers
      raise Error, 'Timeline diagrams use event, not edge' if type == :timeline
      raise Error, "#{type.to_s.capitalize} diagrams do not accept edges or connectors" if %i[gantt kanban].include?(type)
      if type == :sequence
        kind = kind ? kind.to_sym : (dashed ? :return : :call)
        raise Error, "Message kind must be one of #{MESSAGE_KINDS.join(', ')}" unless MESSAGE_KINDS.include?(kind)
        expected_dash = %i[return async].include?(kind)
        if !dashed.nil? && !!dashed != expected_dash
          raise Error, "#{kind} messages require dashed: #{expected_dash}"
        end
        dashed = expected_dash
      elsif kind
        raise Error, 'Message kinds belong in a sequence diagram'
      end
      item = Edge.new(from: Text.clean(from), to: Text.clean(to), label: label && Text.clean(label), dashed: !!dashed, kind: kind, cycle: false)
      @sequence&.append(item)
      @edges << item
    end
    alias message edge

    def depends_on(dependent, dependency_id, cycle: false)
      raise Error, 'depends_on is available only in a dependency diagram' unless type == :dependency
      raise Error, 'cycle must be true or false' unless [true, false].include?(cycle)
      from, to = Text.clean(dependent), Text.clean(dependency_id)
      raise Error, 'A dependency cannot depend on itself' if from == to
      @edges << Edge.new(from: from, to: to, label: cycle ? 'CYCLE' : nil, dashed: cycle, kind: nil, cycle: cycle)
    end

    def zone(id, label = nil, &block)
      previous_zone = @current_zone
      raise Error, 'zone is available only in a deployment diagram' unless type == :deployment
      raise Error, 'Deployment zones cannot nest' if previous_zone
      clean_id = Text.clean(id)
      raise Error, 'Zone IDs must not be blank' if clean_id.strip.empty?
      clean_label = Text.clean(label || id.to_s.tr('_', ' ').sub(/\A./, &:upcase))
      raise Error, 'Zone labels must not be blank' if clean_label.strip.empty?
      @zones << DeploymentZone.new(id: clean_id, label: clean_label)
      @current_zone = clean_id
      instance_eval(&block) if block
    ensure
      @current_zone = previous_zone
    end

    def phase(id, label = nil, columns: HIGH_LEVEL_OPTION_UNSET, &block)
      previous_phase = @current_phase
      unless %i[high_level it_state].include?(type)
        raise Error, 'phase is available only in high-level and IT current-state diagrams'
      end
      raise Error, "#{type == :high_level ? 'High-level' : 'IT current-state'} phases cannot nest" if previous_phase
      raise Error, "A #{type == :high_level ? 'high-level' : 'IT current-state'} phase requires a block" unless block
      clean_id = Text.clean(id)
      raise Error, 'Phase IDs must not be blank' if clean_id.strip.empty?
      if type == :it_state
        raise Error, 'columns is available only in a high-level phase' unless columns.equal?(HIGH_LEVEL_OPTION_UNSET)
        clean_label = Text.clean(Text.clean(label || id.to_s.tr('_', ' ')).upcase)
        raise Error, 'Phase labels must not be blank' if clean_label.strip.empty?
        raise Error, 'Phase labels must be at most 14 characters after uppercase conversion' if clean_label.length > 14
        @phases << ItStatePhase.new(id: clean_id, label: clean_label)
      else
        count = columns.equal?(HIGH_LEVEL_OPTION_UNSET) ? 1 : columns
        raise Error, 'High-level phase columns must be an integer from 1 to 2' unless count.is_a?(Integer) && count.between?(1, 2)
        clean_label = Text.clean(label || id.to_s.tr('_', ' ').sub(/\A./, &:upcase))
        raise Error, 'Phase labels must not be blank' if clean_label.strip.empty?
        if HIGH_LEVEL_RESERVED_CONCERNS.include?(clean_label.downcase)
          raise Error, "#{clean_label} is a reserved concern and cannot be a horizontal phase"
        end
        @phases << HighLevelPhase.new(id: clean_id, label: clean_label, columns: count)
      end
      raise Error, 'Phase labels must not be blank' if clean_label.strip.empty?
      @current_phase = clean_id
      instance_eval(&block)
    ensure
      @current_phase = previous_phase
    end

    def source(id, label = nil, type:, detail: nil)
      raise Error, 'source is available only in a high-level diagram' unless self.type == :high_level
      raise Error, 'Declare a source inside a high-level phase' unless @current_phase
      source_type = type.to_s.to_sym
      unless HIGH_LEVEL_SOURCE_TYPES.include?(source_type)
        raise Error, "Source type must be one of #{HIGH_LEVEL_SOURCE_TYPES.join(', ')}"
      end
      clean_id, clean_label = high_level_identity(id, label, 'Source')
      clean_detail = clean_optional_high_level_text(detail, 'Source detail')
      @sources << HighLevelSource.new(
        id: clean_id, label: clean_label, detail: clean_detail, source_type: source_type, phase: @current_phase
      )
    end

    def component(id, label = nil, role:, detail: nil, focal: false)
      raise Error, 'component is available only in a high-level diagram' unless type == :high_level
      raise Error, 'Declare a component inside a high-level phase' unless @current_phase
      raise Error, 'focal must be true or false' unless [true, false].include?(focal)
      clean_id, clean_label = high_level_identity(id, label, 'Component')
      clean_role = Text.clean(role)
      raise Error, 'Component role must not be blank' if clean_role.strip.empty?
      raise Error, 'Component role must be at most eight characters' if clean_role.length > 8
      @components << HighLevelComponent.new(
        id: clean_id, label: clean_label, detail: clean_optional_high_level_text(detail, 'Component detail'),
        role: clean_role, phase: @current_phase, focal: focal
      )
    end

    def connect(from, to, label = HIGH_LEVEL_OPTION_UNSET, **options)
      raise Error, 'connect is available only in a high-level diagram' unless type == :high_level
      unless label.equal?(HIGH_LEVEL_OPTION_UNSET) && options.empty?
        raise Error, 'High-level connect does not accept a label; optional edge labels are deferred'
      end
      raise Error, 'Declare high-level connections at top level, outside phases' if @current_phase
      @connections << HighLevelConnection.new(from: Text.clean(from), to: Text.clean(to))
    end

    def orchestrate(id, label = nil, detail: nil, concern: 'Orchestration', targets:)
      raise Error, 'orchestrate is available only in a high-level diagram' unless type == :high_level
      raise Error, 'Declare orchestration at high-level top level, outside phases' if @current_phase
      raise Error, 'A high-level diagram accepts at most one orchestration bar' if @orchestration
      raise Error, 'Orchestration targets must be a nonempty array' unless targets.is_a?(Array) && !targets.empty?
      clean_id, clean_label = high_level_identity(id, label, 'Orchestration')
      clean_concern = Text.clean(concern)
      raise Error, 'Orchestration concern must not be blank' if clean_concern.strip.empty?
      @orchestration = HighLevelOrchestration.new(
        id: clean_id, label: clean_label, detail: clean_optional_high_level_text(detail, 'Orchestration detail'),
        concern: clean_concern, targets: targets.map { |target| Text.clean(target) }
      )
    end

    def system(id, label = nil, detail: nil, state: :standard)
      raise Error, 'system is available only in an IT current-state diagram' unless type == :it_state
      raise Error, 'Declare a system inside a phase' unless @current_phase
      clean_state = state.to_s.to_sym
      unless IT_SYSTEM_STATES.include?(clean_state)
        raise Error, "System state must be one of #{IT_SYSTEM_STATES.join(', ')}"
      end
      clean_id = Text.clean(id)
      clean_label = Text.clean(label || id.to_s.tr('_', ' ').sub(/\A./, &:upcase))
      clean_detail = detail && Text.clean(detail)
      raise Error, 'System IDs must not be blank' if clean_id.strip.empty?
      raise Error, 'System labels must not be blank' if clean_label.strip.empty?
      raise Error, 'System detail must not be blank' if clean_detail&.strip&.empty?
      @nodes << Node.new(
        id: clean_id, label: clean_label, detail: clean_detail, emphasis: clean_state == :pain_point,
        kind: clean_state, zone: @current_phase, unavailable: false
      )
    end

    def handoff(from, to, label, style: :neutral, dashed: false)
      raise Error, 'handoff is available only in an IT current-state diagram' unless type == :it_state
      raise Error, 'Declare hand-offs at IT current-state top level, outside phases' if @current_phase
      raise Error, 'dashed must be true or false' unless [true, false].include?(dashed)
      clean_style = style.to_s.to_sym
      unless HANDOFF_STYLES.include?(clean_style)
        raise Error, "Hand-off style must be one of #{HANDOFF_STYLES.join(', ')}"
      end
      clean_label = Text.clean(Text.clean(label).upcase)
      raise Error, 'Hand-off labels must not be blank' if clean_label.strip.empty?
      raise Error, 'Hand-off labels must be at most eight characters after uppercase conversion' if clean_label.length > 8
      clean_from, clean_to = Text.clean(from), Text.clean(to)
      raise Error, 'A hand-off cannot connect a system to itself' if clean_from == clean_to
      @edges << Edge.new(
        from: clean_from, to: clean_to, label: clean_label, dashed: dashed, kind: clean_style,
        cycle: false, emphasis: false
      )
    end

    def crosscut(id, label = nil, detail: nil, concern: HIGH_LEVEL_OPTION_UNSET)
      unless %i[high_level it_state].include?(type)
        raise Error, 'crosscut is available only in high-level and IT current-state diagrams'
      end
      if type == :it_state && !concern.equal?(HIGH_LEVEL_OPTION_UNSET)
        raise Error, 'concern is available only on a high-level crosscut'
      end
      raise Error, "Declare cross-cutting services at #{type == :high_level ? 'high-level' : 'IT current-state'} top level, outside phases" if @current_phase
      clean_id = Text.clean(id)
      clean_label = Text.clean(label || id.to_s.tr('_', ' ').sub(/\A./, &:upcase))
      clean_detail = detail && Text.clean(detail)
      raise Error, 'Cross-cut IDs must not be blank' if clean_id.strip.empty?
      raise Error, 'Cross-cut labels must not be blank' if clean_label.strip.empty?
      raise Error, 'Cross-cut detail must not be blank' if clean_detail&.strip&.empty?
      clean_concern = nil
      if type == :high_level
        raise Error, 'A high-level crosscut requires concern' if concern.equal?(HIGH_LEVEL_OPTION_UNSET)
        clean_concern = Text.clean(concern)
        raise Error, 'Crosscut concern must not be blank' if clean_concern.strip.empty?
      end
      @crosscuts << Crosscut.new(id: clean_id, label: clean_label, detail: clean_detail, concern: clean_concern)
    end

    INFRASTRUCTURE_KINDS.each do |infrastructure_kind|
      define_method(infrastructure_kind) do |id, label = nil, replicas: 1, emphasis: false, &block|
        infrastructure(id, label, kind: infrastructure_kind, replicas: replicas, emphasis: emphasis, &block)
      end
    end

    def artifact(name, version:)
      raise Error, 'artifact is available only in a deployment diagram' unless type == :deployment
      raise Error, 'Declare an artifact inside an infrastructure node' unless @current_infrastructure
      clean_name = Text.clean(name)
      clean_version = version.nil? ? '' : Text.clean(version)
      raise Error, 'Artifact names must not be blank' if clean_name.strip.empty?
      raise Error, 'Artifact version must not be blank' if clean_version.strip.empty?
      @current_infrastructure.artifacts << Artifact.new(name: clean_name, version: clean_version)
    end

    def network(from, to, protocol:, port:, async: false, emphasis: false)
      raise Error, 'network is available only in a deployment diagram' unless type == :deployment
      raise Error, 'Declare network paths at deployment top level, outside zones and infrastructure nodes' if @current_zone || @current_infrastructure
      raise Error, 'Declare network paths at deployment top level, after the zones' if @current_zone || @current_infrastructure
      raise Error, 'async must be true or false' unless [true, false].include?(async)
      raise Error, 'emphasis must be true or false' unless [true, false].include?(emphasis)
      clean_protocol = protocol.nil? ? '' : Text.clean(protocol)
      raise Error, 'Network protocol must not be blank' if clean_protocol.strip.empty?
      unless port.is_a?(Integer) && port.between?(1, 65_535)
        raise Error, 'Network port must be an integer from 1 to 65535'
      end
      clean_from, clean_to = Text.clean(from), Text.clean(to)
      raise Error, 'A network path cannot connect a node to itself' if clean_from == clean_to
      @edges << Edge.new(
        from: clean_from, to: clean_to, label: "#{clean_protocol}:#{port}", dashed: async,
        kind: nil, cycle: false, protocol: clean_protocol, port: port, emphasis: emphasis
      )
    end

    def reply(from, to, annotation = nil, label: annotation) = edge(from, to, label, kind: :return)
    def notify(from, to, annotation = nil, label: annotation) = edge(from, to, label, kind: :async)

    def sequence_items = @sequence&.items || []

    def activate(actor, &block)
      require_sequence_block!(block)
      @sequence.activation(Text.clean(actor)) { instance_eval(&block) }
    end

    def alt(&block)
      require_sequence_block!(block)
      @sequence.fragment(:alt) { instance_eval(&block) }
    end

    def branch(guard, &block)
      require_sequence_block!(block)
      @sequence.branch(sequence_guard(guard)) { instance_eval(&block) }
    end

    def opt(guard, &block)
      require_sequence_block!(block)
      @sequence.fragment(:opt, sequence_guard(guard)) { instance_eval(&block) }
    end

    def loop(guard, &block)
      require_sequence_block!(block)
      @sequence.fragment(:loop, sequence_guard(guard)) { instance_eval(&block) }
    end

    def group(id, label = nil, &block)
      raise Error, 'A state machine does not accept groups' if type == :state
      raise Error, 'Groups are supported only in architecture and flowchart diagrams' unless %i[architecture flowchart].include?(type)
      raise Error, 'Nested groups are not supported' if @current_group
      @current_group = Text.clean(id)
      @groups << Group.new(id: @current_group, label: Text.clean(label || id.to_s.tr('_', ' ').sub(/\A./, &:upcase)))
      instance_eval(&block) if block
    ensure
      @current_group = nil
    end

    def event(date, label, detail: nil, emphasis: false)
      raise Error, 'A state machine uses state and transition, not event' if type == :state
      raise Error, 'Events are supported only in timelines' unless type == :timeline
      @events << Event.new(date: Text.clean(date), label: Text.clean(label), detail: detail && Text.clean(detail), emphasis: !!emphasis)
    end

    def with(style: @style, theme: @theme, scale: @scale)
      mode = theme.to_s.to_sym
      raise Error, 'Theme must be :light, :dark, or :auto' unless %i[light dark auto].include?(mode)
      copy = dup
      copy.instance_variable_set(:@style, Style.fetch(style).name)
      copy.instance_variable_set(:@theme, mode)
      copy.instance_variable_set(:@scale, validated_scale(scale))
      copy.freeze
    end

    def style_profile = Style.fetch(style)

    def effective_handoff_style(item)
      return item.kind unless type == :it_state
      endpoints = nodes.select { |node| [item.from, item.to].include?(node.id) }
      endpoints.any? { |node| node.kind == :pain_point } ? :accent : item.kind
    end

    def layout
      case type
      when :data_flow then Layout::DataFlow.new(self).call
      when :dp_integration then Layout::DPIntegration.new(self).call
      when :dp_security_matrix then Layout::DPSecurityMatrix.new(self).call
      when :er then Layout::ER.new(self).call
      when :db_schema then Layout::DatabaseSchema.new(self).call
      when :uml_class then Layout::UMLClass.new(self).call
      when :quadrant then Layout::Quadrant.new(self).call
      when :venn then Layout::Venn.new(self).call
      when :loop then Layout::Loop.new(self).call
      when :fishbone then Layout::Fishbone.new(self).call
      when :wardley then Layout::Wardley.new(self).call
      when :dependency then Layout::Dependency.new(self).call
      when :deployment then Layout::Deployment.new(self).call
      when :high_level then Layout::HighLevel.new(self).call
      when :it_state then Layout::ItState.new(self).call
      when :swimlane, :process then Layout::Workflow.new(self).call
      when :gantt then Layout::Gantt.new(self).call
      when :kanban then Layout::Kanban.new(self).call
      when :journey then Layout::Journey.new(self).call
      when :story_map then Layout::StoryMap.new(self).call
      when :tree then Layout::Tree.new(self).call
      when :nested then Layout::Nested.new(self).call
      when :layers then Layout::Layers.new(self).call
      when :pyramid then Layout::Pyramid.new(self).call
      when :medallion then Layout::Medallion.new(self).call
      when :sequence then Layout::Sequence.new(self).call
      when :state then Layout::State.new(self).call
      when :timeline then Layout::Timeline.new(self).call
      else Layout::Graph.new(self).call
      end
    end

    def to_svg(id: nil) = SVG.new(self, layout, id: id).render
    def to_motion_svg(storyboard, id: nil, static: false) = SVG.new(self, layout, id: id, motion: storyboard, motion_static: static).render
    def storyboard(&block) = Motion::Presentation.build(self, &block)
    def to_html
      light_paper = style_profile.light.fetch(:paper)
      dark_paper = style_profile.dark.fetch(:paper)
      page_css = case theme
                 when :dark then "html,body{margin:0;min-height:100%;background:#{dark_paper}}body{min-height:100vh}"
                 when :auto then "html,body{margin:0;min-height:100%;background:#{light_paper}}body{min-height:100vh}@media(prefers-color-scheme:dark){html,body{background:#{dark_paper}}}"
                 else "html,body{margin:0;min-height:100%;background:#{light_paper}}body{min-height:100vh}"
                 end
      svg = to_svg
      scroll_region = "<div class=\"sgr-scroll-container\" data-sgr-scroll-container=\"true\" role=\"region\" tabindex=\"0\" aria-label=\"#{CGI.escapeHTML(title)}\" style=\"display:block;box-sizing:border-box;width:100%;max-width:100%;overflow-x:auto;overflow-y:hidden;overscroll-behavior-inline:contain\">#{svg}</div>"
      "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>#{CGI.escapeHTML(title)}</title><style>#{page_css}</style></head><body>#{scroll_region}</body></html>"
    end

    private

    def clean_pyramid_enum(value, default, allowed, name)
      result = value.equal?(FAMILY_OPTION_UNSET) ? default : value.to_sym
      raise Error, "Pyramid #{name} must be one of #{allowed.map { |item| ":#{item}" }.join(', ')}" unless allowed.include?(result)
      result
    rescue NoMethodError
      raise Error, "Pyramid #{name} must be one of #{allowed.map { |item| ":#{item}" }.join(', ')}"
    end

    def clean_pyramid_unit(value)
      return nil if value.equal?(FAMILY_OPTION_UNSET)
      clean = value.nil? ? '' : Text.clean(value)
      raise Error, 'Measured pyramid unit must not be blank' if clean.strip.empty?
      clean
    end

    def validate_pyramid_number!(value, name)
      valid = (value.is_a?(Integer) || value.is_a?(Float)) && value.finite? && value >= 0
      raise Error, "Measured pyramid #{name} must be a finite nonnegative number" unless valid
    end

    def clean_medallion_concern(value)
      return nil if value.nil?
      concern = value.to_sym
      unless MEDALLION_CONCERNS.include?(concern)
        raise Error, "Medallion concern must be one of #{MEDALLION_CONCERNS.join(', ')}"
      end
      concern
    rescue NoMethodError
      raise Error, "Medallion concern must be one of #{MEDALLION_CONCERNS.join(', ')}"
    end

    def append_tree_node(id, label, detail:, focal:, parent_id:, depth:, &block)
      raise Error, 'Tree depth is limited to four tiers; split the hierarchy' if depth > 4
      raise Error, 'focal must be true or false' unless [true, false].include?(focal)
      clean_id, clean_label = family_identity(id, label, 'Tree node')
      clean_detail = detail && Text.clean(detail)
      raise Error, 'Tree node detail must not be blank when supplied' if clean_detail&.strip&.empty?
      item = TreeNode.new(
        id: clean_id, label: clean_label, detail: clean_detail, focal: focal,
        parent_id: parent_id, depth: depth
      )
      @tree_nodes << item
      previous = @current_tree_parent
      @current_tree_parent = item
      instance_eval(&block) if block
      item
    ensure
      @current_tree_parent = previous
    end

    def family_identity(id, label, kind)
      clean_id = Text.clean(id)
      clean_label = Text.clean(label || id.to_s.tr('_', ' ').sub(/\A./, &:upcase))
      raise Error, "#{kind} ID must not be blank" if clean_id.strip.empty?
      raise Error, "#{kind} label must not be blank" if clean_label.strip.empty?
      [clean_id, clean_label]
    end

    def clean_layer_axis(value)
      clean = value.equal?(FAMILY_OPTION_UNSET) ? 'Abstraction'.freeze : Text.clean(value)
      raise Error, 'Layer-stack axis label must not be blank' if clean.strip.empty?
      clean
    end

    def clean_layer_indicator(value)
      clean = value.equal?(FAMILY_OPTION_UNSET) ? :up : value.to_sym
      raise Error, 'Layer-stack indicator must be :up or :down' unless %i[up down].include?(clean)
      clean
    rescue NoMethodError
      raise Error, 'Layer-stack indicator must be :up or :down'
    end

    def clean_high_level_cluster(value)
      cleaned = value.equal?(HIGH_LEVEL_OPTION_UNSET) ? 'Cluster'.freeze : Text.clean(value)
      raise Error, 'High-level cluster label must not be blank' if cleaned.strip.empty?
      cleaned
    end

    def high_level_identity(id, label, kind)
      clean_id = Text.clean(id)
      clean_label = Text.clean(label || id.to_s.tr('_', ' ').sub(/\A./, &:upcase))
      raise Error, "#{kind} ID must not be blank" if clean_id.strip.empty?
      raise Error, "#{kind} label must not be blank" if clean_label.strip.empty?
      [clean_id, clean_label]
    end

    def clean_optional_high_level_text(value, name)
      return nil if value.nil?
      cleaned = Text.clean(value)
      raise Error, "#{name} must not be blank" if cleaned.strip.empty?
      cleaned
    end

    def clean_it_heading(value, name)
      return nil if value.equal?(IT_OPTION_UNSET) || value.nil?
      cleaned = Text.clean(value)
      raise Error, "IT current-state #{name} must not be blank" if cleaned.strip.empty?
      cleaned
    end

    def infrastructure(id, label, kind:, replicas:, emphasis:, &block)
      previous_infrastructure = @current_infrastructure
      raise Error, "#{kind} is available only in a deployment diagram" unless type == :deployment
      raise Error, 'Declare infrastructure inside a zone' unless @current_zone
      raise Error, 'Infrastructure nodes cannot nest' if previous_infrastructure
      unless replicas.is_a?(Integer) && replicas.positive?
        raise Error, 'Infrastructure replicas must be a positive integer'
      end
      raise Error, 'emphasis must be true or false' unless [true, false].include?(emphasis)
      clean_id = Text.clean(id)
      clean_label = Text.clean(label || id.to_s.tr('_', ' ').sub(/\A./, &:upcase))
      item = Node.new(
        id: clean_id, label: clean_label, emphasis: emphasis, kind: kind, zone: @current_zone,
        replicas: replicas, artifacts: [], unavailable: false
      )
      @nodes << item
      @current_infrastructure = item
      instance_eval(&block) if block
    ensure
      @current_infrastructure = previous_infrastructure
    end

    def validated_scale(value)
      scale = value.to_s.to_sym
      raise Error, 'Timeline scale must be :auto, :date, or :ordered' unless %i[auto date ordered].include?(scale)
      raise Error, 'scale applies only to timelines' if type != :timeline && scale != :auto
      scale
    end

    def require_sequence_block!(block)
      raise Error, 'Activation and frame operations belong in a sequence diagram' unless type == :sequence
      raise Error, 'Sequence operations require a block' unless block
    end

    def sequence_guard(value)
      guard = Text.clean(value)
      raise Error, 'Sequence guards must not be blank' if guard.strip.empty?
      guard
    end

    def clean_org_text(value)
      return nil if value.equal?(ORG_OPTION_UNSET) || value.nil?
      cleaned = Text.clean(value)
      raise Error, 'Org-chart invocation and scope must not be blank' if cleaned.strip.empty?
      cleaned
    end

    def append_dependency(id, label, kind:, version: nil, registry: nil)
      clean_id = Text.clean(id)
      clean_label = Text.clean(label || id.to_s.tr('_', ' ').sub(/\A./, &:upcase))
      raise Error, 'Dependency IDs must not be blank' if clean_id.strip.empty?
      raise Error, 'Dependency labels must not be blank' if clean_label.strip.empty?
      @nodes << Node.new(id: clean_id, label: clean_label, kind: kind, emphasis: false, unavailable: false,
                         version: version && Text.clean(version), registry: registry && Text.clean(registry))
    end

    def clean_transition_part(value, name)
      return nil if value.nil?
      cleaned = Text.clean(value)
      raise Error, "Transition #{name} must not be blank" if cleaned.strip.empty?
      cleaned
    end

    def org_rule(kind, label, owner)
      raise Error, "#{kind} is available only in an org chart" unless type == :org_chart
      clean_label = Text.clean(label)
      raise Error, "#{kind.to_s.capitalize} text must not be blank" if clean_label.strip.empty?
      owner_id = Text.clean(owner)
      raise Error, "#{kind.to_s.capitalize} owner must not be blank" if owner_id.strip.empty?
      @rules << OrgRule.new(kind: kind, label: clean_label, owner: owner_id)
    end

    def validate_flowchart!
      nodes.each do |node|
        incoming = edges.select { |e| e.to == node.id }
        outgoing = edges.select { |e| e.from == node.id }
        case node.kind
        when :decision
          raise Error, "Decision #{node.id} has more than three exits; split the decision" if outgoing.size > 3
          if outgoing.any? { |e| !e.label || e.label.strip.empty? }
            raise Error, "Label every exit from decision #{node.id}"
          end
        when :start
          raise Error, "Start #{node.id} cannot have incoming connections" unless incoming.empty?
        when :finish
          raise Error, "Finish #{node.id} cannot have outgoing connections" unless outgoing.empty?
        when :merge
          unless incoming.size.between?(2, 3) && outgoing.size == 1
            raise Error, "Merge #{node.id} needs two or three inputs and one output"
          end
        end
      end
    end

    def validate!
      return validate_data_flow! if type == :data_flow
      return validate_dp_integration! if type == :dp_integration
      return validate_dp_security_matrix! if type == :dp_security_matrix
      return validate_er! if type == :er
      return validate_db_schema! if type == :db_schema
      return validate_uml_class! if type == :uml_class
      return validate_quadrant! if type == :quadrant
      return validate_venn! if type == :venn
      return validate_loop! if type == :loop
      return validate_fishbone! if type == :fishbone
      return validate_wardley! if type == :wardley
      return validate_state! if type == :state
      return validate_deployment! if type == :deployment
      return validate_high_level! if type == :high_level
      return validate_it_state! if type == :it_state
      return validate_workflow! if %i[swimlane process].include?(type)
      return validate_gantt! if type == :gantt
      return validate_kanban! if type == :kanban
      return validate_journey! if type == :journey
      return validate_story_map! if type == :story_map
      return validate_tree! if type == :tree
      return validate_nested! if type == :nested
      return validate_layers! if type == :layers
      return validate_pyramid! if type == :pyramid
      return validate_medallion! if type == :medallion
      raise Error, 'A timeline needs at least one event' if type == :timeline && events.empty?
      raise Error, 'A diagram needs at least one node' if type != :timeline && nodes.empty?
      raise Error, 'Limit: 32 nodes/events, 64 edges, 3 groups. Split this diagram or use Mermaid.' if nodes.size > 32 || events.size > 32 || edges.size > 64 || groups.size > 3
      raise Error, 'Node IDs must be nonempty and unique' if nodes.any? { |n| n.id.empty? } || nodes.map(&:id).uniq.size != nodes.size
      raise Error, 'Group IDs must be unique' if groups.map(&:id).uniq.size != groups.size
      raise Error, 'Use at most two emphasized nodes/events' if (nodes + events).count(&:emphasis) > 2
      groups.each { |g| raise Error, "Group #{g.id} is empty" unless nodes.any? { |n| n.group == g.id } }
      edges.each do |e|
        [e.from, e.to].each { |id| raise Error, "Unknown node: #{id}" unless nodes.any? { |n| n.id == id } }
      end
      if type == :sequence
        raise Error, 'Sequence limit: five participants and twelve messages; split the sequence' if nodes.size > 5 || edges.size > 12
        raise Error, 'Use at most two headline success messages' if edges.count { |e| e.kind == :success } > 2
      end
      validate_dependency! if type == :dependency
      validate_flowchart! if type == :flowchart
      if type == :org_chart
        validate_org_chart!
      end
    end

    def validate_pyramid!
      raise Error, 'Pyramid diagrams need four to six levels' unless levels.size.between?(4, 6)
      raise Error, 'Pyramid level IDs must be unique' unless levels.map(&:id).uniq.size == levels.size
      raise Error, 'A pyramid allows at most one focal level' if levels.count(&:focal) > 1
      raise Error, 'The pyramid base cannot be focal' if orientation == :pyramid && levels.first&.focal
      if mode == :hierarchy
        raise Error, 'Hierarchy mode supports only orientation: :pyramid' unless orientation == :pyramid
        raise Error, 'Hierarchy mode does not accept a unit' if unit
        return
      end
      raise Error, 'Measured pyramid mode requires a nonblank unit' unless unit
      first = levels.first.from
      raise Error, 'The first measured from value must be positive and finite' unless first.positive?
      levels.each do |item|
        if item.to > item.from
          raise Error, "Measured pyramid level #{item.id} must have to less than or equal to from"
        end
      end
      levels.each_cons(2) do |left, right|
        unless left.to == right.from
          raise Error, "Measured pyramid chain is broken: #{left.id}.to must equal #{right.id}.from"
        end
      end
      levels.flat_map { |item| [item.from, item.to] }.each do |amount|
        width = amount.fdiv(first) * 480.0
        center = 280.0
        endpoints_distinct = (center - width / 2.0).to_s != (center + width / 2.0).to_s
        if amount.positive? && (!width.finite? || width.zero? || !endpoints_distinct)
          raise Error, 'Measured pyramid scale cannot preserve a positive boundary in SVG coordinates; use a less extreme scale'
        end
      end
    end

    def validate_medallion!
      raise Error, 'Medallion diagrams need three to six tiers' unless tiers.size.between?(3, 6)
      ids = tiers.map(&:id) + write_paths.map(&:id)
      raise Error, 'Medallion tier and write-path IDs must be unique' unless ids.uniq.size == ids.size
      raise Error, 'A medallion needs exactly one explicit focal tier' unless tiers.count(&:focal) == 1
      raise Error, 'A medallion permits at most one archive tier' if tiers.count(&:archive) > 1
      archive = tiers.find(&:archive)
      raise Error, 'An archive tier must be final' if archive && archive != tiers.last
      raise Error, 'Focal and archive tiers cannot coincide' if tiers.any? { |item| item.focal && item.archive }
      tiers.each do |item|
        if item.concern && (item.focal || item.archive)
          raise Error, 'Concern is forbidden on focal and archive tiers'
        end
      end
      raise Error, 'Medallion diagrams allow at most two write paths' if write_paths.size > 2
      concerned = tiers.count(&:concern) + write_paths.count(&:concern)
      raise Error, 'Medallion diagrams allow at most two concerned tiers and write paths total' if concerned > 2
      unless promotions.size == tiers.size - 1
        raise Error, 'Medallion diagrams require exactly one promotion between every adjacent tier'
      end
      expected = tiers.each_cons(2).map { |left, right| [left.id, right.id] }
      actual = promotions.map { |item| [item.from, item.to] }
      unless actual == expected
        raise Error, 'Medallion promotions must connect each adjacent tier exactly once in declaration order'
      end
    end

    def validate_tree!
      roots = tree_nodes.select { |item| item.parent_id.nil? }
      raise Error, 'A tree diagram needs exactly one root' unless roots.one?
      raise Error, 'Tree node IDs must be unique' unless tree_nodes.map(&:id).uniq.size == tree_nodes.size
      raise Error, 'A tree diagram allows at most one focal node' if tree_nodes.count(&:focal) > 1
      tree_nodes.group_by(&:depth).each do |depth, items|
        raise Error, "Tree breadth is limited to five nodes in tier #{depth}; split the hierarchy" if items.size > 5
      end
      tree_nodes.group_by(&:parent_id).each do |parent_id, items|
        next if parent_id.nil? || items.size <= 5
        raise Error, "Tree parent #{parent_id} has more than five children; split the hierarchy"
      end
      tree_nodes.reject { |item| item.parent_id.nil? }.each do |item|
        parent = tree_nodes.find { |candidate| candidate.id == item.parent_id }
        raise Error, "Unknown tree parent: #{item.parent_id}" unless parent
        raise Error, "Tree node #{item.id} skips a hierarchy tier" unless item.depth == parent.depth + 1
      end
    end

    def validate_nested!
      unless containment_scopes.size.between?(3, 5)
        raise Error, 'Nested-containment diagrams need three to five levels'
      end
      if containment_scopes.map(&:id).uniq.size != containment_scopes.size
        raise Error, 'Containment scope IDs must be unique'
      end
      roots = containment_scopes.select { |item| item.parent_id.nil? }
      raise Error, 'A nested-containment diagram needs exactly one outer scope' unless roots.one?
      containment_scopes.each do |item|
        children = containment_scopes.select { |candidate| candidate.parent_id == item.id }
        if children.size > 1
          raise Error, "Containment scope #{item.id} must contain only one inner scope"
        end
      end
      containment_scopes.each_cons(2) do |outer, inner|
        unless inner.parent_id == outer.id && inner.depth == outer.depth + 1
          raise Error, 'Nested-containment scopes must form one uninterrupted chain'
        end
      end
    end

    def validate_layers!
      raise Error, 'Layer-stack diagrams need four to six layers' unless layers.size.between?(4, 6)
      raise Error, 'Layer IDs must be unique' unless layers.map(&:id).uniq.size == layers.size
      raise Error, 'A layer stack needs exactly one focal layer' unless layers.count(&:focal) == 1
      numeric = layers.map { |item| item.index.match?(/\AL?\d+\z/i) }
      if numeric.any? && !numeric.all?
        raise Error, 'Layer indices cannot mix numeric and semantic forms'
      end
      if numeric.all?
        values = layers.map { |item| item.index.sub(/\AL/i, '').to_i }
        differences = values.each_cons(2).map { |left, right| right - left }
        unless differences.all? { |difference| difference == differences.first && difference.abs == 1 }
          raise Error, 'Numeric layer indices must form one contiguous ascending or descending sequence'
        end
      end
      raise Error, 'Layer indices must be unique' unless layers.map(&:index).uniq.size == layers.size
    end

    def validate_high_level!
      raise Error, 'High-level diagrams need three to five horizontal phases' unless phases.size.between?(3, 5)
      if phases.sum(&:columns) > 5
        raise Error, 'High-level diagrams allow at most five weighted columns so every component stays contained'
      end
      raise Error, 'High-level diagrams need one to four sources' unless sources.size.between?(1, 4)
      raise Error, 'High-level diagram limit: eight components' if components.size > 8
      raise Error, 'High-level diagram limit: twelve data connections' if connections.size > 12
      raise Error, 'High-level diagram limit: two crosscuts' if crosscuts.size > 2

      phases.each_with_index do |phase, index|
        source_count = sources.count { |item| item.phase == phase.id }
        component_count = components.count { |item| item.phase == phase.id }
        if index.zero?
          unless source_count.between?(1, 4) && component_count.zero?
            raise Error, 'The first high-level phase contains one to four sources and no components'
          end
        elsif !component_count.between?(1, 2) || source_count.positive?
          raise Error, "Later high-level phase #{phase.id} needs one or two components and no sources"
        end
      end

      ids = phases.map(&:id) + sources.map(&:id) + components.map(&:id) + crosscuts.map(&:id)
      ids << orchestration.id if orchestration
      if ids.any? { |id| id.strip.empty? } || ids.uniq.size != ids.size
        raise Error, 'High-level IDs must be nonblank and unique across phases, sources, components, orchestration, and crosscuts'
      end
      raise Error, 'A high-level diagram needs exactly one explicit focal component' unless components.count(&:focal) == 1

      endpoint_ids = sources.map(&:id) + components.map(&:id)
      phase_order = phases.each_with_index.to_h { |phase, index| [phase.id, index] }
      item_phase = (sources + components).to_h { |item| [item.id, item.phase] }
      connections.each do |item|
        raise Error, "Unknown high-level endpoint: #{item.from}" unless endpoint_ids.include?(item.from)
        raise Error, "Unknown high-level component: #{item.to}" unless components.any? { |component| component.id == item.to }
        unless phase_order.fetch(item_phase.fetch(item.from)) < phase_order.fetch(item_phase.fetch(item.to))
          raise Error, 'High-level data connections must advance to a later phase; same-phase, backward, and query links are deferred'
        end
      end
      if connections.group_by { |item| [item.from, item.to] }.values.any? { |items| items.size > 1 }
        raise Error, 'Duplicate high-level connections are not supported'
      end
      if connections.group_by(&:from).any? { |_from, items| items.size > 3 }
        raise Error, 'A high-level source or component has more than three outgoing connections; introduce an explicit hub'
      end

      concerns = crosscuts.map(&:concern)
      if orchestration
        if orchestration.targets.uniq.size != orchestration.targets.size
          raise Error, 'Orchestration targets must be unique'
        end
        orchestration.targets.each do |target|
          component = components.find { |item| item.id == target }
          raise Error, "Unknown orchestration target: #{target}" unless component
          top = components.find { |item| item.phase == component.phase }
          unless component.equal?(top)
            raise Error, "Orchestration target #{target} must be the top component in phase #{component.phase}; a straight drop to a lower stacked component would be hidden"
          end
        end
        concerns.unshift(orchestration.concern)
      end
      if concerns.map(&:downcase).uniq.size != concerns.size
        raise Error, 'Every orchestration and crosscut concern must be unique for honest 1:1 vertical pairing'
      end
    end

    def validate_it_state!
      unless phases.size.between?(2, 4)
        raise Error, 'IT current-state diagrams need two to four phases'
      end
      raise Error, 'IT current-state diagram limit: 16 systems. Split the landscape.' if nodes.size > 16
      raise Error, 'IT current-state diagram limit: 24 hand-offs. Split the landscape.' if edges.size > 24
      raise Error, 'IT current-state diagram limit: three cross-cutting services.' if crosscuts.size > 3
      phases.each do |item|
        count = nodes.count { |node| node.zone == item.id }
        unless count.between?(1, 5)
          raise Error, "IT current-state phase #{item.id} needs one to five systems"
        end
      end
      ids = phases.map(&:id) + nodes.map(&:id) + crosscuts.map(&:id)
      raise Error, 'IT current-state IDs must be nonblank and unique across phases, systems, and cross-cuts' if ids.any? { |id| id.strip.empty? } || ids.uniq.size != ids.size
      raise Error, 'Use at most two pain-point systems' if nodes.count { |node| node.kind == :pain_point } > 2
      edges.each do |item|
        source = nodes.find { |node| node.id == item.from }
        target = nodes.find { |node| node.id == item.to }
        raise Error, "Unknown IT current-state system: #{item.from}" unless source
        raise Error, "Unknown IT current-state system: #{item.to}" unless target
        source_phase = phases.index { |phase| phase.id == source.zone }
        target_phase = phases.index { |phase| phase.id == target.zone }
        source_order = nodes.select { |node| node.zone == source.zone }.index(source)
        target_order = nodes.select { |node| node.zone == target.zone }.index(target)
        backward = source_phase > target_phase || (source_phase == target_phase && source_order > target_order)
        next unless backward
        raise Error, 'A backward hand-off requires an external endpoint' unless [source, target].any? { |node| node.kind == :external }
        raise Error, 'A backward hand-off with an external endpoint must be dashed' unless item.dashed
      end
      if edges.group_by { |item| [item.from, item.to] }.values.any? { |items| items.size > 1 }
        raise Error, 'Duplicate hand-offs for the same ordered system pair are not supported'
      end
    end

    def validate_deployment!
      raise Error, 'A deployment diagram needs at least one zone' if zones.empty?
      raise Error, 'Deployment diagram limit: three zones. Split the diagram by environment.' if zones.size > 3
      raise Error, 'Deployment diagram limit: six infrastructure nodes. Split the diagram by environment.' if nodes.size > 6
      artifact_count = nodes.sum { |node| node.artifacts.size }
      raise Error, 'Deployment diagram limit: nine artifact chips. Split the diagram by environment.' if artifact_count > 9
      raise Error, 'Deployment diagram limit: eight network paths. Split the diagram by environment.' if edges.size > 8
      if zones.any? { |item| item.id.strip.empty? } || zones.map(&:id).uniq.size != zones.size
        raise Error, 'Zone IDs must not be blank and must be unique'
      end
      raise Error, 'Zone labels must not be blank' if zones.any? { |item| item.label.strip.empty? }
      zones.each do |item|
        raise Error, "Zone #{item.id} is empty; place at least one infrastructure node inside it" unless nodes.any? { |node| node.zone == item.id }
      end
      raise Error, 'A deployment diagram needs at least one infrastructure node' if nodes.empty?
      if nodes.any? { |item| item.id.strip.empty? } || nodes.map(&:id).uniq.size != nodes.size
        raise Error, 'Infrastructure node IDs must be nonblank and unique'
      end
      raise Error, 'Infrastructure labels must not be blank' if nodes.any? { |item| item.label.strip.empty? }
      unless (zones.map(&:id) & nodes.map(&:id)).empty?
        raise Error, 'Zone and infrastructure node IDs share one namespace and must be unique'
      end
      nodes.each do |item|
        raise Error, "Infrastructure node #{item.id} must contain at least one versioned artifact" if item.artifacts.empty?
      end
      edges.each do |item|
        [item.from, item.to].each do |id|
          raise Error, "Unknown infrastructure node: #{id}" unless nodes.any? { |node| node.id == id }
        end
      end
      if edges.group_by { |item| [item.from, item.to] }.values.any? { |items| items.size > 1 }
        raise Error, 'Duplicate network paths for the same ordered node pair are not supported'
      end
      if nodes.count(&:emphasis) + edges.count(&:emphasis) > 2
        raise Error, 'Use at most two focal infrastructure nodes or network paths'
      end
    end

    def validate_dependency!
      raise Error, 'Dependency diagram limit: nine nodes. Collapse a leaf cluster and state its count.' if nodes.size > 9
      raise Error, 'Dependency diagram limit: fourteen relationships. Split the diagram.' if edges.size > 14
      if edges.group_by { |item| [item.from, item.to] }.values.any? { |items| items.size > 1 }
        raise Error, 'Duplicate dependency relationships are not supported'
      end
      cycle_edges = edges.select(&:cycle)
      raise Error, 'Dependency diagrams highlight at most one cycle' if cycle_edges.size > 1
      forward = edges.reject(&:cycle)
      raise Error, 'The remaining relationships must be acyclic after removing the marked cycle' if dependency_cycle?(forward)
      if cycle_edges.one?
        item = cycle_edges.first
        unless dependency_reachable?(item.to, item.from, forward)
          raise Error, "Marked cycle #{item.from} -> #{item.to} does not close a path from #{item.to} back to #{item.from}"
        end
      elsif edges.none? { |item| edges.count { |other| other.to == item.to } > 1 }
      raise Error, 'Dependency data is tree-shaped; use :tree with nested root and child blocks'
      end
      nodes.each do |item|
        label_budget = item.kind == :external ? 94 : 132
        if Text.width(item.label) > label_budget
          raise Error, "Dependency label #{item.label.inspect} does not fit the fixed 160px dependency box; shorten it"
        end
        next unless item.kind == :external
        metadata = "#{item.version} · #{item.registry}"
        if Text.width(metadata, 10, font: :mono) > 128
          raise Error, "External metadata #{metadata.inspect} does not fit the fixed 160px dependency box; shorten it"
        end
      end
      ranks = dependency_ranks(forward)
      raise Error, 'Dependency diagram limit: five rank layers. Collapse a leaf cluster or split the diagram.' if ranks.values.max.to_i >= 5
    end

    def dependency_cycle?(relationships)
      visiting, visited = {}, {}
      visit = lambda do |id|
        return true if visiting[id]
        return false if visited[id]
        visiting[id] = true
        found = relationships.select { |item| item.from == id }.any? { |item| visit.call(item.to) }
        visiting.delete(id)
        visited[id] = true
        found
      end
      nodes.any? { |item| visit.call(item.id) }
    end

    def dependency_reachable?(origin, target, relationships)
      seen, pending = [], [origin]
      until pending.empty?
        id = pending.shift
        return true if id == target
        next if seen.include?(id)
        seen << id
        pending.concat(relationships.select { |item| item.from == id }.map(&:to))
      end
      false
    end

    def dependency_ranks(relationships)
      indegree = nodes.to_h { |item| [item.id, 0] }
      relationships.each { |item| indegree[item.to] += 1 }
      queue = nodes.map(&:id).select { |id| indegree[id].zero? }
      ranks = nodes.to_h { |item| [item.id, 0] }
      until queue.empty?
        id = queue.shift
        relationships.select { |item| item.from == id }.each do |item|
          ranks[item.to] = [ranks[item.to], ranks[id] + 1].max
          indegree[item.to] -= 1
          queue << item.to if indegree[item.to].zero?
        end
      end
      ranks
    end

    def validate_state!
      unless states.size.between?(2, 12)
        raise Error, 'State machine limit: two to twelve states'
      end
      if states.any? { |item| item.id.strip.empty? } || states.map(&:id).uniq.size != states.size
        raise Error, 'State IDs must be nonblank and unique'
      end
      raise Error, 'A state machine needs exactly one initial state' unless @initial_count == 1
      raise Error, 'Initial state must not be blank' if initial_state.strip.empty?
      raise Error, "Unknown initial state: #{initial_state}" unless state_ids.include?(initial_state)
      unless final_states.size.between?(1, 2) && final_states.uniq.size == final_states.size
        raise Error, 'A state machine needs one or two unique final states'
      end
      raise Error, 'Final state must not be blank' if final_states.any? { |id| id.strip.empty? }
      final_states.each { |id| raise Error, "Unknown final state: #{id}" unless state_ids.include?(id) }
      raise Error, 'A state machine needs at least one transition' if transitions.empty?
      if transitions.size > states.size * 2
        raise Error, 'State machine limit: at most twice as many transitions as states'
      end
      raise Error, 'Use at most two emphasized states' if states.count(&:emphasis) > 2
      transitions.each do |item|
        raise Error, 'Transition source must not be blank' if item.from.strip.empty?
        raise Error, 'Transition target must not be blank' if item.to.strip.empty?
        raise Error, "Unknown transition source: #{item.from}" unless state_ids.include?(item.from)
        raise Error, "Unknown transition target: #{item.to}" unless state_ids.include?(item.to)
      end
      if transitions.group_by { |item| [item.from, item.to] }.values.any? { |items| items.size > 1 }
        raise Error, 'A state machine allows one transition per ordered pair, including one self-loop per state'
      end
      states.each do |item|
        incoming = transitions.count { |edge| edge.to == item.id }
        outgoing = transitions.count { |edge| edge.from == item.id }
        raise Error, "State #{item.id} has more than four incoming transitions" if incoming > 4
        raise Error, "State #{item.id} has more than four outgoing transitions" if outgoing > 4
      end
      final_states.each do |id|
        raise Error, "Final state #{id} cannot have outgoing transitions" if transitions.any? { |item| item.from == id }
      end

      reachable = graph_reachable(initial_state, :forward)
      missing = state_ids - reachable
      raise Error, "State not reachable from initial: #{missing.join(', ')}" unless missing.empty?
      can_finish = final_states.flat_map { |id| graph_reachable(id, :reverse) }.uniq
      stranded = state_ids - can_finish
      raise Error, "State cannot reach a final state: #{stranded.join(', ')}" unless stranded.empty?
      validate_state_cycles!
    end

    def state_ids = states.map(&:id)

    def graph_reachable(origin, direction)
      seen, pending = [], [origin]
      until pending.empty?
        id = pending.shift
        next if seen.include?(id)
        seen << id
        next_ids = if direction == :forward
          transitions.select { |item| item.from == id }.map(&:to)
        else
          transitions.select { |item| item.to == id }.map(&:from)
        end
        pending.concat(next_ids)
      end
      seen
    end

    def validate_state_cycles!
      unassigned = state_ids.dup
      components = []
      until unassigned.empty?
        seed = unassigned.first
        component = unassigned.select do |candidate|
          graph_reachable(seed, :forward).include?(candidate) && graph_reachable(candidate, :forward).include?(seed)
        end
        components << component if component.size > 1
        unassigned -= component.empty? ? [seed] : component
      end
      return if components.empty?
      raise Error, 'State machines support one simple directed cycle' if components.size > 1
      members = components.first
      unless members.size.between?(2, 4)
        raise Error, 'A directed state cycle must contain two to four states'
      end
      internal = transitions.select { |item| members.include?(item.from) && members.include?(item.to) && item.from != item.to }
      simple = internal.size == members.size && members.all? do |id|
        internal.count { |item| item.from == id } == 1 && internal.count { |item| item.to == id } == 1
      end
      raise Error, 'State machines support one simple directed cycle; nested or overlapping cycles are outside this release' unless simple
    end

    def validate_org_chart!
      raise Error, 'Org chart limit: twelve visible nodes. Split the chart into an overview and details.' if nodes.size > 12
      raise Error, 'An org chart allows one parent per node' if edges.group_by(&:to).values.any? { |v| v.size > 1 }
      if (parent, reports = edges.group_by(&:from).find { |_, values| values.size > 5 })
        raise Error, "Org chart limit: five direct reports under #{parent}. Add a grouping owner."
      end
      raise Error, 'Use at most one emphasized org-chart node' if nodes.count(&:emphasis) > 1
      raise Error, 'Org chart limit: two rule callouts' if rules.size > 2
      raise Error, 'Org chart limit: three setup-gap callouts' if setup_gaps.size > 3
      rules.each do |rule|
        next if nodes.any? { |node| node.id == rule.owner }
        raise Error, "Unknown #{rule.kind} owner: #{rule.owner}"
      end
      setup_gaps.each do |gap|
        next if nodes.any? { |node| node.id == gap.owner }
        raise Error, "Unknown setup-gap owner: #{gap.owner}"
      end

      active, depths = {}, nodes.to_h { |node| [node.id, 1] }
      visit = lambda do |id|
        raise Error, 'An org chart cannot contain a cycle' if active[id]
        return depths[id] if active.key?(id)
        active[id] = true
        child_depth = edges.select { |edge| edge.from == id }.map { |edge| visit.call(edge.to) }.max || 0
        active[id] = false
        depths[id] = child_depth + 1
      end
      nodes.each { |node| visit.call(node.id) }
      raise Error, 'Org chart limit: four tiers. Split the hierarchy into detail charts.' if depths.values.max > 4
    end
  end
end
