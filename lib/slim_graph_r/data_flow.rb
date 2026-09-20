# frozen_string_literal: true
module SlimGraphR
  DataFlowRole = Struct.new(:id, :label, :key, keyword_init: true)
  DataFlowStep = Struct.new(:id, :label, :ordinal, :focal, keyword_init: true)
  DataFlowTransfer = Struct.new(:id, :label, :detail, :role, :step, :tool, :input, :output, :focal, keyword_init: true)
  DataFlowHandoff = Struct.new(:from, :to, :kind, :label, keyword_init: true)

  module DataFlowDSL
    PAYLOADS = %i[web dataset table file stream].freeze
    HANDOFF_KINDS = %i[ordinary trigger focal publish].freeze
    OPTION_UNSET = Object.new.freeze

    attr_reader :data_flow_roles, :data_flow_steps, :data_flow_transfers, :data_flow_handoffs

    def initialize(...)
      @data_flow_roles = []
      @data_flow_steps = []
      @data_flow_transfers = []
      @data_flow_handoffs = []
      super
    end

    def role(id, label = nil, key: nil, **options)
      raise Error, 'role is available only in a data-flow diagram' unless type == :data_flow
      raise Error, "Unknown data-flow role options: #{options.keys.join(', ')}" unless options.empty?
      clean_id, clean_label = data_flow_identity(id, label, 'Role')
      clean_key = key.nil? ? '' : Text.clean(key)
      unless clean_key.match?(/\A[A-Z]{1,3}\z/)
        raise Error, 'Data-flow role key must be uppercase and one to three characters'
      end
      @data_flow_roles << DataFlowRole.new(id: clean_id, label: clean_label, key: clean_key)
    end

    def step(id, label = nil, focal: OPTION_UNSET, **options)
      unless type == :data_flow
        options[:focal] = focal unless focal.equal?(OPTION_UNSET)
        return super(id, label, **options)
      end
      raise Error, "Unknown data-flow step options: #{options.keys.join(', ')}" unless options.empty?
      focal = false if focal.equal?(OPTION_UNSET)
      raise Error, 'focal must be true or false' unless [true, false].include?(focal)
      clean_id, clean_label = data_flow_identity(id, label, 'Step')
      @data_flow_steps << DataFlowStep.new(
        id: clean_id, label: clean_label, ordinal: @data_flow_steps.size + 1, focal: focal
      )
    end

    def transfer(id, label = nil, role: OPTION_UNSET, step: OPTION_UNSET, tool: nil, detail: nil, input: nil, output: nil, focal: false, **options)
      raise Error, 'transfer is available only in a data-flow diagram' unless type == :data_flow
      raise Error, "Unknown data-flow transfer options: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'focal must be true or false' unless [true, false].include?(focal)
      clean_id, clean_label = data_flow_identity(id, label, 'Transfer')
      if role.equal?(OPTION_UNSET) || step.equal?(OPTION_UNSET)
        raise Error, 'A data-flow transfer requires role: and step:'
      end
      clean_tool = tool.nil? ? '' : Text.clean(tool)
      raise Error, 'Data-flow transfer tool is required and must not be blank' if clean_tool.strip.empty?
      clean_detail = detail.nil? ? nil : Text.clean(detail)
      raise Error, 'Data-flow transfer detail must not be blank when supplied' if clean_detail&.strip&.empty?
      @data_flow_transfers << DataFlowTransfer.new(
        id: clean_id, label: clean_label, detail: clean_detail, role: Text.clean(role), step: Text.clean(step), tool: clean_tool,
        input: data_flow_payload(input, 'input'), output: data_flow_payload(output, 'output'), focal: focal
      )
    end

    def handoff(from, to, positional_label = OPTION_UNSET, kind: OPTION_UNSET, label: OPTION_UNSET, **options)
      unless type == :data_flow
        forwarded = options.dup
        forwarded[:kind] = kind unless kind.equal?(OPTION_UNSET)
        forwarded[:label] = label unless label.equal?(OPTION_UNSET)
        return super(from, to, positional_label, **forwarded) unless positional_label.equal?(OPTION_UNSET)
        return super(from, to, **forwarded)
      end
      raise Error, 'Data-flow handoff labels use label: and not a positional label' unless positional_label.equal?(OPTION_UNSET)
      raise Error, "Unknown data-flow handoff options: #{options.keys.join(', ')}" unless options.empty?
      unless HANDOFF_KINDS.include?(kind)
        raise Error, "Data-flow handoff kind must be one of #{HANDOFF_KINDS.join(', ')}"
      end
      clean_label = label.equal?(OPTION_UNSET) ? nil : Text.clean(label)
      if kind == :focal
        if clean_label.nil? || clean_label.strip.empty? || clean_label != clean_label.upcase
          raise Error, 'A focal data-flow handoff requires a nonblank uppercase payload label'
        end
      elsif !label.equal?(OPTION_UNSET)
        raise Error, 'Only a focal data-flow handoff accepts a label'
      end
      @data_flow_handoffs << DataFlowHandoff.new(
        from: Text.clean(from), to: Text.clean(to), kind: kind, label: clean_label
      )
    end

    def node(...)
      raise Error, 'Data-flow diagrams use role, step, transfer, and handoff, not generic node' if type == :data_flow
      super
    end

    def edge(...)
      raise Error, 'Data-flow diagrams use handoff, not generic edge' if type == :data_flow
      super
    end

    private

    def data_flow_identity(id, label, kind)
      clean_id = Text.clean(id)
      clean_label = Text.clean(label || id.to_s.tr('_', ' ').sub(/\A./, &:upcase))
      raise Error, "Data-flow #{kind.downcase} ID must not be blank" if clean_id.strip.empty?
      raise Error, "Data-flow #{kind.downcase} label must not be blank" if clean_label.strip.empty?
      [clean_id, clean_label]
    end

    def data_flow_payload(value, side)
      return nil if value.nil?
      payload = value.to_s.to_sym
      unless PAYLOADS.include?(payload)
        raise Error, "Data-flow #{side} payload must be one of #{PAYLOADS.join(', ')}"
      end
      payload
    rescue NoMethodError
      raise Error, "Data-flow #{side} payload must be one of #{PAYLOADS.join(', ')}"
    end

    def validate_data_flow!
      unless nodes.empty? && edges.empty? && groups.empty? && events.empty? && rules.empty? && states.empty? &&
             transitions.empty? && zones.empty? && phases.empty? && crosscuts.empty?
        raise Error, 'Data-flow diagrams use only role, step, transfer, and handoff; generic graph records are not accepted'
      end
      unless data_flow_roles.size.between?(2, 4)
        raise Error, 'Data-flow diagrams need two to four roles'
      end
      unless data_flow_steps.size.between?(2, 6)
        raise Error, 'Data-flow diagrams need two to six steps'
      end
      unless data_flow_transfers.size.between?(2, 16)
        raise Error, 'Data-flow diagrams need two to sixteen transfers'
      end
      raise Error, 'Data-flow diagrams allow at most twenty handoffs' if data_flow_handoffs.size > 20
      {
        'role' => data_flow_roles, 'step' => data_flow_steps, 'transfer' => data_flow_transfers
      }.each do |name, items|
        raise Error, "Data-flow #{name} IDs must be unique" unless items.map(&:id).uniq.size == items.size
      end
      raise Error, 'Data-flow role keys must be unique' unless data_flow_roles.map(&:key).uniq.size == data_flow_roles.size
      cells = data_flow_transfers.group_by { |item| [item.role, item.step] }
      if cells.any? { |_cell, items| items.size > 1 }
        raise Error, 'Only one transfer may occupy a data-flow role and step cell'
      end
      role_ids = data_flow_roles.map(&:id)
      step_ids = data_flow_steps.map(&:id)
      data_flow_transfers.each do |item|
        raise Error, "Unknown data-flow role: #{item.role}" unless role_ids.include?(item.role)
        raise Error, "Unknown data-flow step: #{item.step}" unless step_ids.include?(item.step)
      end
      if data_flow_handoffs.group_by { |item| [item.from, item.to] }.any? { |_pair, items| items.size > 1 }
        raise Error, 'Duplicate handoff for the same ordered transfer pair is not supported'
      end
      transfers = data_flow_transfers.to_h { |item| [item.id, item] }
      role_order = data_flow_roles.each_with_index.to_h { |item, index| [item.id, index] }
      step_order = data_flow_steps.each_with_index.to_h { |item, index| [item.id, index] }
      data_flow_handoffs.each do |item|
        source = transfers[item.from]
        target = transfers[item.to]
        raise Error, "Unknown transfer in data-flow diagram: #{item.from}" unless source
        raise Error, "Unknown transfer in data-flow diagram: #{item.to}" unless target
        raise Error, 'A data-flow handoff cannot connect a transfer to itself' if source.equal?(target)
        case item.kind
        when :trigger
          raise Error, 'A trigger handoff must stay in the same step' unless source.step == target.step
          unless role_order.fetch(source.role) < role_order.fetch(target.role)
            raise Error, 'A trigger handoff must follow downward role order'
          end
        when :ordinary, :publish
          unless step_order.fetch(source.step) < step_order.fetch(target.step)
            raise Error, "A #{item.kind} handoff must advance to a later step"
          end
        when :focal
          raise Error, 'A focal handoff must cross roles' if source.role == target.role
          unless step_order.fetch(source.step) < step_order.fetch(target.step)
            raise Error, 'A focal handoff must advance to a later step'
          end
        end
      end
      raise Error, 'A data-flow diagram needs exactly one focal step' unless data_flow_steps.count(&:focal) == 1
      raise Error, 'A data-flow diagram needs exactly one focal transfer' unless data_flow_transfers.count(&:focal) == 1
      focal_handoffs = data_flow_handoffs.select { |item| item.kind == :focal }
      raise Error, 'A data-flow diagram needs exactly one focal handoff' unless focal_handoffs.one?
      focal_step = data_flow_steps.find(&:focal)
      focal_transfer = data_flow_transfers.find(&:focal)
      focal_handoff = focal_handoffs.first
      unless focal_handoff.to == focal_transfer.id && focal_transfer.step == focal_step.id
        raise Error, 'The focal handoff must target the focal transfer in the focal step'
      end
      [data_flow_roles, data_flow_steps, data_flow_transfers, data_flow_handoffs].each do |items|
        items.each(&:freeze)
        items.freeze
      end
    end
  end
end

SlimGraphR::Diagram.prepend(SlimGraphR::DataFlowDSL)
