# frozen_string_literal: true
require 'date'

module SlimGraphR
  GanttPhase = Struct.new(:id, :label, keyword_init: true)
  GanttTask = Struct.new(:id, :label, :start, :finish, :phase, :focal, keyword_init: true)
  GanttMilestone = Struct.new(:id, :label, :on, :phase, keyword_init: true)
  GanttMarker = Struct.new(:id, :label, :on, keyword_init: true)
  KanbanCard = Struct.new(:id, :label, :ticket, :owner, :state, :focal, keyword_init: true)
  KanbanColumn = Struct.new(:id, :label, :wip_limit, :cards, keyword_init: true)

  class Diagram
    PLANNING_OPTION_UNSET = Object.new.freeze
    KANBAN_STATES = %i[default blocked waiting done].freeze

    alias planning_boards_original_phase phase unless method_defined?(:planning_boards_original_phase)

    def phase(id, label = nil, columns: HIGH_LEVEL_OPTION_UNSET, &block)
      return planning_boards_original_phase(id, label, columns: columns, &block) unless type == :gantt
      previous_phase = @current_gantt_phase
      raise Error, 'Gantt phase does not accept columns' unless columns.equal?(HIGH_LEVEL_OPTION_UNSET)
      raise Error, 'Gantt phases cannot nest' if previous_phase
      raise Error, 'A Gantt phase requires a block' unless block
      clean_id, clean_label = planning_identity(id, label, 'Gantt phase')
      @gantt_phases << GanttPhase.new(id: clean_id, label: clean_label)
      @current_gantt_phase = clean_id
      instance_eval(&block)
    ensure
      @current_gantt_phase = previous_phase if type == :gantt
    end

    def task(id, label = nil, start:, finish:, focal: false)
      raise Error, 'task is available only in a Gantt diagram' unless type == :gantt
      raise Error, 'Declare a Gantt task inside a phase' unless @current_gantt_phase
      raise Error, 'Gantt task focal must be true or false' unless [true, false].include?(focal)
      clean_id, clean_label = planning_identity(id, label, 'Gantt task')
      start_date = planning_date(start, 'Task start')
      finish_date = planning_date(finish, 'Task finish')
      unless finish_date > start_date
        raise Error, 'Gantt task finish must be after start; tasks use the half-open interval [start, finish)'
      end
      @gantt_tasks << GanttTask.new(
        id: clean_id, label: clean_label, start: Text.clean(start), finish: Text.clean(finish),
        phase: @current_gantt_phase, focal: focal
      )
    end

    def milestone(id, label = nil, on:, phase: nil)
      raise Error, 'milestone is available only in a Gantt diagram' unless type == :gantt
      raise Error, 'Declare milestones at Gantt top level, outside phases' if @current_gantt_phase
      clean_id, clean_label = planning_identity(id, label, 'Gantt milestone')
      planning_date(on, 'Milestone date')
      clean_phase = phase.nil? ? nil : planning_reference(phase, 'Milestone phase')
      @gantt_milestones << GanttMilestone.new(id: clean_id, label: clean_label, on: Text.clean(on), phase: clean_phase)
    end

    def marker(id, label = nil, on:)
      raise Error, 'marker is available only in a Gantt diagram' unless type == :gantt
      raise Error, 'Declare markers at Gantt top level, outside phases' if @current_gantt_phase
      clean_id, clean_label = planning_identity(id, label, 'Gantt marker')
      planning_date(on, 'Marker date')
      @gantt_markers << GanttMarker.new(id: clean_id, label: clean_label, on: Text.clean(on))
    end

    def column(id, label = nil, wip_limit: PLANNING_OPTION_UNSET, &block)
      raise Error, 'column is available only in a Kanban diagram' unless type == :kanban
      previous_column = @current_kanban_column
      raise Error, 'Kanban columns cannot nest' if previous_column
      raise Error, 'A Kanban column requires a block' unless block
      limit = wip_limit.equal?(PLANNING_OPTION_UNSET) ? nil : wip_limit
      unless limit.nil? || (limit.is_a?(Integer) && limit.positive?)
        raise Error, 'Kanban wip_limit must be a positive integer when supplied'
      end
      clean_id, clean_label = planning_identity(id, label, 'Kanban column')
      item = KanbanColumn.new(id: clean_id, label: clean_label, wip_limit: limit, cards: [])
      @kanban_columns << item
      @current_kanban_column = item
      instance_eval(&block)
    ensure
      @current_kanban_column = previous_column if type == :kanban
    end

    def card(id, label = nil, ticket: nil, owner: nil, state: :default, focal: false)
      raise Error, 'card is available only in a Kanban diagram' unless type == :kanban
      raise Error, 'Declare a Kanban card inside a column' unless @current_kanban_column
      raise Error, 'Kanban card focal must be true or false' unless [true, false].include?(focal)
      clean_state = state.to_sym
      unless KANBAN_STATES.include?(clean_state)
        raise Error, "Kanban card state must be one of #{KANBAN_STATES.join(', ')}"
      end
      clean_id, clean_label = planning_identity(id, label, 'Kanban card')
      clean_ticket = planning_optional_text(ticket, 'Kanban ticket')
      clean_owner = planning_optional_text(owner, 'Kanban owner')
      @current_kanban_column.cards << KanbanCard.new(
        id: clean_id, label: clean_label, ticket: clean_ticket, owner: clean_owner,
        state: clean_state, focal: focal
      )
    rescue NoMethodError
      raise Error, "Kanban card state must be one of #{KANBAN_STATES.join(', ')}"
    end

    private

    def planning_identity(id, label, kind)
      clean_id = Text.clean(id)
      clean_label = Text.clean(label || id.to_s.tr('_-', ' ').split.map(&:capitalize).join(' '))
      raise Error, "#{kind} ID must not be blank" if clean_id.strip.empty?
      raise Error, "#{kind} label must not be blank" if clean_label.strip.empty?
      [clean_id, clean_label]
    rescue NoMethodError, TypeError
      raise Error, "#{kind} ID and label must be strings or symbols"
    end

    def planning_reference(value, kind)
      clean = Text.clean(value)
      raise Error, "#{kind} must not be blank" if clean.strip.empty?
      clean
    rescue NoMethodError, TypeError
      raise Error, "#{kind} must be a string or symbol"
    end

    def planning_optional_text(value, kind)
      return nil if value.nil?
      clean = Text.clean(value)
      raise Error, "#{kind} must not be blank when supplied" if clean.strip.empty?
      clean
    end

    def planning_date(value, kind)
      unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        raise Error, "#{kind} must be a valid Gregorian YYYY-MM-DD date"
      end
      Date.iso8601(value, Date::GREGORIAN)
    rescue ArgumentError
      raise Error, "#{kind} must be a valid Gregorian YYYY-MM-DD date"
    end

    def validate_gantt!
      raise Error, 'Gantt diagrams use fixed calendar direction and do not accept direction' unless direction == :down
      raise Error, 'Gantt diagrams allow at most four phases' if gantt_phases.size > 4
      raise Error, 'Gantt diagrams allow at most twelve tasks' if gantt_tasks.size > 12
      milestone_limit = gantt_tasks.empty? ? 8 : 8
      raise Error, "Gantt diagrams allow at most #{milestone_limit} milestones" if gantt_milestones.size > milestone_limit
      raise Error, 'Gantt diagrams allow at most two markers' if gantt_markers.size > 2
      raise Error, 'A Gantt diagram needs at least one task or milestone' if gantt_tasks.empty? && gantt_milestones.empty?
      raise Error, 'A Gantt diagram allows at most one focal task' if gantt_tasks.count(&:focal) > 1
      {
        'phase' => gantt_phases, 'task' => gantt_tasks,
        'milestone' => gantt_milestones, 'marker' => gantt_markers
      }.each do |kind, items|
        raise Error, "Gantt #{kind} IDs must be unique" unless items.map(&:id).uniq.size == items.size
      end
      phase_ids = gantt_phases.map(&:id)
      gantt_milestones.each do |item|
        raise Error, "Unknown Gantt milestone phase: #{item.phase}" if item.phase && !phase_ids.include?(item.phase)
      end
    end

    def validate_kanban!
      raise Error, 'Kanban diagrams use fixed board direction and do not accept direction' unless direction == :down
      raise Error, 'Kanban diagrams need two to five columns' unless kanban_columns.size.between?(2, 5)
      raise Error, 'Kanban column IDs must be unique' unless kanban_columns.map(&:id).uniq.size == kanban_columns.size
      cards = kanban_columns.flat_map(&:cards)
      raise Error, 'Kanban card IDs must be unique across the board' unless cards.map(&:id).uniq.size == cards.size
      raise Error, 'A Kanban diagram allows at most one focal card' if cards.count(&:focal) > 1
    end
  end
end
