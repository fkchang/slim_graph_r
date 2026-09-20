# frozen_string_literal: true
module SlimGraphR
  WorkflowLane = Struct.new(:id, :label, :key, keyword_init: true)
  WorkflowStage = Struct.new(:id, :label, :number, :focal, keyword_init: true)
  WorkflowCard = Struct.new(:id, :label, :lane, :stage, :tool, :detail, :input, :output, :focal, keyword_init: true)
  WorkflowHandoff = Struct.new(:from, :to, :focal, :label, :dashed, keyword_init: true)
  WorkflowTrigger = Struct.new(:from, :to, :label, keyword_init: true)

  class Diagram
    WORKFLOW_UNSET = Object.new.freeze
    WORKFLOW_PAYLOADS = %w[LS DB TB FL WB].freeze

    alias workflow_original_node node
    alias workflow_original_edge edge
    alias workflow_it_state_handoff handoff

    def lane(id, label = nil, key: WORKFLOW_UNSET)
      ensure_workflow_type!('lane')
      if type == :swimlane
        raise Error, 'Swimlane lanes do not accept key; keys are process-only' unless key.equal?(WORKFLOW_UNSET)
        clean_key = nil
      else
        raise Error, 'Process lane key is required' if key.equal?(WORKFLOW_UNSET)
        clean_key = Text.clean(Text.clean(key).upcase)
        unless !clean_key.strip.empty? && clean_key.length.between?(1, 3)
          raise Error, 'Process lane key must be one to three rendered characters'
        end
      end
      clean_id, clean_label = workflow_identity(id, label, 'Workflow lane')
      @workflow_lanes << WorkflowLane.new(id: clean_id, label: clean_label, key: clean_key)
    rescue NoMethodError, TypeError
      raise Error, 'Process lane key must be a nonblank string of one to three rendered characters'
    end

    def stage(id, label = nil, focal: WORKFLOW_UNSET)
      ensure_workflow_type!('stage')
      if type == :swimlane && !focal.equal?(WORKFLOW_UNSET)
        raise Error, 'Swimlane stages do not accept focal; focal stages are process-only'
      end
      value = focal.equal?(WORKFLOW_UNSET) ? false : focal
      raise Error, 'Process stage focal must be true or false' unless [true, false].include?(value)
      clean_id, clean_label = workflow_identity(id, label, 'Workflow stage')
      @workflow_stages << WorkflowStage.new(id: clean_id, label: clean_label, number: @workflow_stages.size + 1, focal: value)
    end

    def activity(id, label = nil, lane:, stage:, detail: nil, focal: WORKFLOW_UNSET, **options)
      raise Error, 'activity is available only in a swimlane diagram' unless type == :swimlane
      raise Error, "Activity does not accept: #{options.keys.join(', ')}" unless options.empty?
      focal_value = focal.equal?(WORKFLOW_UNSET) ? false : focal
      raise Error, 'Swimlane activity focal must be true or false' unless [true, false].include?(focal_value)
      clean_id, clean_label = workflow_identity(id, label, 'Activity')
      clean_detail = detail.nil? ? nil : Text.clean(detail)
      raise Error, 'Swimlane activity detail must not be blank when supplied' if clean_detail&.strip&.empty?
      @activities << WorkflowCard.new(
        id: clean_id, label: clean_label, lane: workflow_reference(lane, 'lane'), stage: workflow_reference(stage, 'stage'),
        tool: nil, detail: clean_detail, input: nil, output: nil, focal: focal_value
      )
    end

    def operation(id, label = nil, lane:, stage:, tool:, detail: nil, input: WORKFLOW_UNSET, output: WORKFLOW_UNSET, focal: false)
      raise Error, 'operation is available only in a process diagram' unless type == :process
      raise Error, 'Process operation focal must be true or false' unless [true, false].include?(focal)
      clean_id, clean_label = workflow_identity(id, label, 'Operation')
      clean_tool = Text.clean(tool)
      raise Error, 'Process operation tool must not be blank' if clean_tool.strip.empty?
      clean_detail = detail.nil? ? nil : Text.clean(detail)
      raise Error, 'Process operation detail must not be blank when supplied' if clean_detail&.strip&.empty?
      @operations << WorkflowCard.new(
        id: clean_id, label: clean_label, lane: workflow_reference(lane, 'lane'), stage: workflow_reference(stage, 'stage'),
        tool: clean_tool, detail: clean_detail,
        input: workflow_payload(input, 'input'), output: workflow_payload(output, 'output'), focal: focal
      )
    rescue NoMethodError, TypeError
      raise Error, 'Process operation tool must be a nonblank string'
    end

    def handoff(from, to, label = WORKFLOW_UNSET, focal: WORKFLOW_UNSET, dashed: WORKFLOW_UNSET, **options)
      unless %i[swimlane process].include?(type)
        if type == :it_state && focal.equal?(WORKFLOW_UNSET)
          forwarded = options
          forwarded = forwarded.merge(dashed: dashed) unless dashed.equal?(WORKFLOW_UNSET)
          return workflow_it_state_handoff(from, to, label, **forwarded)
        end
        raise Error, 'handoff is available only in workflow and IT current-state diagrams'
      end
      if type == :process && !label.equal?(WORKFLOW_UNSET)
        raise Error, 'Process handoffs are unlabelled; use trigger for a labelled return path'
      end
      raise Error, "Workflow handoff does not accept: #{options.keys.join(', ')}" unless options.empty?
      if type == :process && !focal.equal?(WORKFLOW_UNSET)
        raise Error, 'Process handoffs do not accept focal; focal styling derives from the focal operation'
      end
      value = focal.equal?(WORKFLOW_UNSET) ? false : focal
      raise Error, 'Swimlane handoff focal must be true or false' unless [true, false].include?(value)
      dash_value = dashed.equal?(WORKFLOW_UNSET) ? false : dashed
      if type == :process && !dashed.equal?(WORKFLOW_UNSET)
        raise Error, 'Process handoffs do not accept dashed; use trigger for a dashed return path'
      end
      raise Error, 'Swimlane handoff dashed must be true or false' unless [true, false].include?(dash_value)
      clean_label = label.equal?(WORKFLOW_UNSET) ? nil : Text.clean(label)
      raise Error, 'Swimlane handoff label must not be blank when supplied' if clean_label&.strip&.empty?
      @workflow_handoffs << WorkflowHandoff.new(
        from: workflow_reference(from, 'card'), to: workflow_reference(to, 'card'), focal: value,
        label: clean_label, dashed: dash_value
      )
    end

    def trigger(from, to, label)
      raise Error, 'trigger is available only in a process diagram' unless type == :process
      raise Error, 'A process accepts at most one backward trigger' if @workflow_trigger
      clean = Text.clean(label)
      raise Error, 'Process trigger label must not be blank' if clean.strip.empty?
      @workflow_trigger = WorkflowTrigger.new(from: workflow_reference(from, 'card'), to: workflow_reference(to, 'card'), label: clean)
    rescue NoMethodError, TypeError
      raise Error, 'Process trigger label must be a nonblank string'
    end

    def node(*args, **options, &block)
      raise Error, "Use #{type == :process ? 'operation' : 'activity'} inside a #{type} diagram" if %i[swimlane process].include?(type)
      workflow_original_node(*args, **options, &block)
    end

    def edge(*args, **options)
      raise Error, 'Use handoff inside a workflow diagram' if %i[swimlane process].include?(type)
      workflow_original_edge(*args, **options)
    end

    private

    def ensure_workflow_type!(name)
      return if %i[swimlane process].include?(type)
      raise Error, "#{name} is available only in workflow diagrams"
    end

    def workflow_identity(id, label, kind)
      clean_id = Text.clean(id)
      raise Error, "#{kind} ID must not be blank" if clean_id.strip.empty?
      clean_label = label.nil? ? Text.clean(clean_id.tr('_-', ' ').split.map(&:capitalize).join(' ')) : Text.clean(label)
      raise Error, "#{kind} label must not be blank" if clean_label.strip.empty?
      [clean_id, clean_label]
    rescue NoMethodError, TypeError
      raise Error, "#{kind} ID and label must be strings or symbols"
    end

    def workflow_reference(value, kind)
      clean = Text.clean(value)
      raise Error, "Workflow #{kind} reference must not be blank" if clean.strip.empty?
      clean
    rescue NoMethodError, TypeError
      raise Error, "Workflow #{kind} reference must be a string or symbol"
    end

    def workflow_payload(value, name)
      return nil if value.equal?(WORKFLOW_UNSET) || value.nil?
      clean = Text.clean(value)
      unless WORKFLOW_PAYLOADS.include?(clean)
        raise Error, "Process #{name} payload must be one of #{WORKFLOW_PAYLOADS.join(', ')} or null"
      end
      clean
    rescue NoMethodError, TypeError
      raise Error, "Process #{name} payload must be one of #{WORKFLOW_PAYLOADS.join(', ')} or null"
    end

    def validate_workflow!
      cards = type == :process ? operations : activities
      card_name = type == :process ? 'operation' : 'activity'
      card_plural = type == :process ? 'operations' : 'activities'
      raise Error, 'Workflow diagrams use fixed horizontal direction: :right' unless direction == :right
      raise Error, 'Workflow diagrams need one to six lanes' unless workflow_lanes.size.between?(1, 6)
      raise Error, 'Workflow diagrams need one to twelve stages' unless workflow_stages.size.between?(1, 12)
      raise Error, "A #{type} diagram needs at least one #{card_name}" if cards.empty?
      raise Error, "Workflow diagram limit: 24 #{card_plural}" if cards.size > 24
      raise Error, 'Workflow diagram limit: 24 handoffs' if workflow_handoffs.size > 24

      all_ids = workflow_lanes.map(&:id) + workflow_stages.map(&:id) + cards.map(&:id)
      if all_ids.uniq.size != all_ids.size
        raise Error, "Workflow IDs must be unique across lanes, stages, and #{card_plural}"
      end
      lanes = workflow_lanes.map(&:id)
      stages = workflow_stages.map(&:id)
      cards.each do |card|
        raise Error, "Unknown workflow lane: #{card.lane}" unless lanes.include?(card.lane)
        raise Error, "Unknown workflow stage: #{card.stage}" unless stages.include?(card.stage)
      end
      if cards.group_by { |card| [card.lane, card.stage] }.values.any? { |items| items.size > 1 }
        raise Error, 'Workflow diagrams allow one card per lane and stage cell'
      end
      card_ids = cards.map(&:id)
      workflow_handoffs.each do |item|
        [item.from, item.to].each { |id| raise Error, "Unknown workflow card: #{id}" unless card_ids.include?(id) }
        validate_forward_workflow_edge!(item, cards)
      end
      if workflow_handoffs.group_by { |item| [item.from, item.to] }.values.any? { |items| items.size > 1 }
        raise Error, 'Duplicate workflow handoffs are not supported'
      end

      if type == :swimlane
        raise Error, 'A swimlane allows at most one focal handoff' if workflow_handoffs.count(&:focal) > 1
        raise Error, 'A swimlane allows at most one focal activity' if activities.count(&:focal) > 1
        return
      end

      raise Error, 'Process lane keys must be unique' unless workflow_lanes.map(&:key).uniq.size == workflow_lanes.size
      raise Error, 'A process diagram needs exactly one focal stage' unless workflow_stages.count(&:focal) == 1
      raise Error, 'A process diagram needs exactly one focal operation' unless operations.count(&:focal) == 1
      first_stage, last_stage = workflow_stages.first.id, workflow_stages.last.id
      operations.each do |item|
        raise Error, 'A process operation in the first stage cannot have a supplied first-stage input' if item.stage == first_stage && item.input
        raise Error, 'A process operation in the last stage cannot have a supplied last-stage output' if item.stage == last_stage && item.output
      end
      if workflow_trigger
        [workflow_trigger.from, workflow_trigger.to].each { |id| raise Error, "Unknown workflow card: #{id}" unless card_ids.include?(id) }
        from = cards.find { |card| card.id == workflow_trigger.from }
        to = cards.find { |card| card.id == workflow_trigger.to }
        unless workflow_stage_index(from.stage) > workflow_stage_index(to.stage)
          raise Error, 'A process trigger must be a backward path to an earlier stage'
        end
      end
    end

    def validate_forward_workflow_edge!(item, cards)
      from = cards.find { |card| card.id == item.from }
      to = cards.find { |card| card.id == item.to }
      unless workflow_stage_index(from.stage) < workflow_stage_index(to.stage)
        raise Error, 'Workflow handoffs must advance to a later stage; same-stage and backward handoffs are not supported'
      end
    end

    def workflow_stage_index(id) = workflow_stages.index { |stage| stage.id == id }
  end
end
