# frozen_string_literal: true
module SlimGraphR
  WardleyComponent = Struct.new(:id, :label, :evolution, :visibility, :evolving_to, keyword_init: true)
  WardleyDependency = Struct.new(:from, :to, keyword_init: true)

  module WardleyDSL
    EVOLUTION = %i[genesis custom_built product commodity].freeze

    attr_reader :wardley_components, :wardley_dependencies

    def initialize(...)
      @wardley_components = []
      @wardley_dependencies = []
      super
    end

    def component(id, label = nil, **options)
      return super unless type == :wardley
      allowed = %i[evolution visibility evolving_to]
      unknown = options.keys - allowed
      raise Error, "Unknown Wardley component options: #{unknown.join(', ')}" unless unknown.empty?
      raise Error, 'Wardley component evolution is required' unless options.key?(:evolution)
      raise Error, 'Wardley component visibility is required' unless options.key?(:visibility)
      evolution = wardley_evolution(options[:evolution], 'evolution')
      evolving_to = options.key?(:evolving_to) ? wardley_evolution(options[:evolving_to], 'evolving_to') : nil
      if evolving_to && EVOLUTION.index(evolving_to) != EVOLUTION.index(evolution) + 1
        raise Error, 'Wardley evolving_to must name the strictly adjacent band to the right'
      end
      @wardley_components << WardleyComponent.new(
        id: wardley_text(id, 'Wardley component ID'),
        label: wardley_text(label, 'Wardley component label'),
        evolution: evolution,
        visibility: wardley_visibility(options[:visibility]),
        evolving_to: evolving_to
      )
    end

    def depends_on(from, to, **options)
      return super unless type == :wardley
      raise Error, 'Wardley dependencies do not accept labels, cycles, protocols, or runtime semantics' unless options.empty?
      @wardley_dependencies << WardleyDependency.new(
        from: wardley_text(from, 'Wardley dependency from'),
        to: wardley_text(to, 'Wardley dependency to')
      )
    end

    def node(...)
      raise Error, 'Wardley maps use dedicated component records' if type == :wardley
      super
    end

    def edge(...)
      raise Error, 'Wardley maps use dedicated dependencies' if type == :wardley
      super
    end

    def flow(...)
      raise Error, 'Wardley maps do not infer dependencies from a flow' if type == :wardley
      super
    end

    def group(...)
      raise Error, 'Wardley maps do not accept generic groups' if type == :wardley
      super
    end

    private

    def wardley_text(value, name)
      raise Error, "#{name} must be a String or Symbol" unless value.is_a?(String) || value.is_a?(Symbol)
      clean = Text.clean(value)
      raise Error, "#{name} must not be blank" if clean.strip.empty?
      clean
    end

    def wardley_evolution(value, name)
      candidate = value.to_sym if value.is_a?(String) || value.is_a?(Symbol)
      raise Error, "Wardley #{name} must be one of #{EVOLUTION.join(', ')}" unless EVOLUTION.include?(candidate)
      candidate
    end

    def wardley_visibility(value)
      unless (value.is_a?(Integer) || value.is_a?(Float)) && value.finite? && value.between?(0, 1)
        raise Error, 'Wardley visibility must be a real finite number in [0, 1]'
      end
      value.to_f
    end

    def validate_wardley!
      unless nodes.empty? && edges.empty? && groups.empty? && events.empty? && rules.empty? && states.empty? &&
             transitions.empty? && zones.empty? && phases.empty? && crosscuts.empty?
        raise Error, 'Wardley maps accept only dedicated component and dependency records'
      end
      raise Error, 'A Wardley map requires two to nine components' unless wardley_components.size.between?(2, 9)
      raise Error, 'A Wardley map requires one to twelve dependencies' unless wardley_dependencies.size.between?(1, 12)
      raise Error, 'Wardley component IDs must be unique' unless wardley_components.map(&:id).uniq.size == wardley_components.size
      if wardley_dependencies.map { |item| [item.from, item.to] }.uniq.size != wardley_dependencies.size
        raise Error, 'Wardley dependencies must be unique'
      end
      raise Error, 'A Wardley dependency cannot point to itself' if wardley_dependencies.any? { |item| item.from == item.to }
      ids = wardley_components.map(&:id)
      wardley_dependencies.each do |item|
        [item.from, item.to].each { |id| raise Error, "Unknown Wardley component: #{id}" unless ids.include?(id) }
      end
      isolated = ids.reject { |id| wardley_dependencies.any? { |item| item.from == id || item.to == id } }
      unless isolated.empty?
        raise Error, "Every Wardley component must be incident to a dependency; unconnected: #{isolated.join(', ')}"
      end
      raise Error, 'A Wardley map allows at most two evolving components' if wardley_components.count(&:evolving_to) > 2
      wardley_components.each(&:freeze)
      wardley_dependencies.each(&:freeze)
      wardley_components.freeze
      wardley_dependencies.freeze
    end
  end
end

SlimGraphR::Diagram.prepend(SlimGraphR::WardleyDSL)
