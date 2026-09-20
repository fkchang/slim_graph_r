# frozen_string_literal: true
module SlimGraphR
  ERField = Struct.new(:id, :label, :key, :type, :qualifier, keyword_init: true)
  EREntity = Struct.new(:id, :label, :kind, :focal, :fields, keyword_init: true)
  ERRelationship = Struct.new(:from, :to, :from_cardinality, :to_cardinality, :label, keyword_init: true)

  module ERDSL
    CARDINALITIES = %w[1 N 0..1 0..* 1..*].freeze
    FIELD_KEYS = %i[primary foreign].freeze
    ENTITY_KINDS = %i[entity aggregate_root join_table].freeze
    ER_UNSET = Object.new.freeze

    attr_reader :entities, :relationships

    def initialize(...)
      @entities = []
      @relationships = []
      @current_er_entity = nil
      super
    end

    def entity(id, label = ER_UNSET, focal: false, kind: :entity, **options, &block)
      raise Error, 'entity is available only in an ER diagram' unless type == :er
      raise Error, 'ER entities cannot be nested' if @current_er_entity
      raise Error, "Unknown ER entity options: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'Entity label is required and must not be blank' if label.equal?(ER_UNSET)
      raise Error, 'Entity focal must be true or false' unless [true, false].include?(focal)
      clean_kind = er_kind(kind)
      clean_id = er_text(id, 'Entity ID')
      clean_label = er_text(label, 'Entity label')
      item = EREntity.new(id: clean_id, label: clean_label, kind: clean_kind, focal: focal, fields: [])
      @entities << item
      previous = @current_er_entity
      @current_er_entity = item
      instance_eval(&block) if block
      item
    ensure
      @current_er_entity = previous if defined?(previous)
    end

    def field(id, label = ER_UNSET, key: ER_UNSET, type: ER_UNSET, qualifier: ER_UNSET, **options)
      raise Error, 'field is available only in an ER diagram' unless self.type == :er
      raise Error, 'An ER field must be declared inside an entity' unless @current_er_entity
      raise Error, "Unknown ER field options: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'Field label is required and must not be blank' if label.equal?(ER_UNSET)
      clean_key = if key.equal?(ER_UNSET)
        nil
      else
        candidate = key.to_s.to_sym
        unless FIELD_KEYS.include?(candidate)
          raise Error, "Field key must be primary, foreign, or omitted"
        end
        candidate
      end
      clean_type = type.equal?(ER_UNSET) ? nil : er_text(type, 'Field type')
      clean_qualifier = qualifier.equal?(ER_UNSET) ? nil : er_text(qualifier, 'Field qualifier')
      @current_er_entity.fields << ERField.new(
        id: er_text(id, 'Field ID'), label: er_text(label, 'Field label'), key: clean_key,
        type: clean_type, qualifier: clean_qualifier
      )
    rescue NoMethodError
      raise Error, 'Field key must be primary, foreign, or omitted'
    end

    def relationship(from_id, to_id, from: ER_UNSET, to: ER_UNSET, label: ER_UNSET, **options)
      raise Error, 'relationship is available only in an ER diagram' unless type == :er
      raise Error, 'An ER relationship must be declared outside entity blocks' if @current_er_entity
      raise Error, "Unknown ER relationship options: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'Relationship requires from and to cardinalities' if from.equal?(ER_UNSET) || to.equal?(ER_UNSET)
      from_cardinality = er_cardinality(from, 'from')
      to_cardinality = er_cardinality(to, 'to')
      clean_from = er_text(from_id, 'Relationship from entity')
      clean_to = er_text(to_id, 'Relationship to entity')
      raise Error, 'ER self-relationships are not supported in this bounded release' if clean_from == clean_to
      clean_label = label.equal?(ER_UNSET) ? nil : er_text(label, 'Relationship label')
      pair = [clean_from, clean_to].sort
      if @relationships.any? { |item| [item.from, item.to].sort == pair }
        raise Error, "Duplicate relationship between #{clean_from} and #{clean_to}"
      end
      @relationships << ERRelationship.new(
        from: clean_from, to: clean_to, from_cardinality: from_cardinality,
        to_cardinality: to_cardinality, label: clean_label
      )
    end

    def node(...)
      raise Error, 'ER diagrams use dedicated ER entity and field records' if type == :er
      super
    end

    def edge(...)
      raise Error, 'ER diagrams use relationship with explicit endpoint cardinalities' if type == :er
      super
    end

    def flow(...)
      raise Error, 'ER diagrams use relationship with explicit endpoint cardinalities' if type == :er
      super
    end

    def group(...)
      raise Error, 'An ER diagram does not accept groups' if type == :er
      super
    end

    private

    def er_text(value, name)
      raise Error, "#{name} must be a String or Symbol" unless value.is_a?(String) || value.is_a?(Symbol)
      clean = Text.clean(value)
      raise Error, "#{name} is required and must not be blank" if clean.strip.empty?
      clean
    end

    def er_cardinality(value, endpoint)
      candidate = value.is_a?(String) ? Text.clean(value) : nil
      unless CARDINALITIES.include?(candidate)
        raise Error, "Relationship #{endpoint} cardinality must be one of #{CARDINALITIES.join(', ')}"
      end
      candidate
    end

    def er_kind(value)
      candidate = value.to_s.to_sym
      unless ENTITY_KINDS.include?(candidate)
        raise Error, "Entity kind must be one of #{ENTITY_KINDS.join(', ')}"
      end
      candidate
    rescue NoMethodError
      raise Error, "Entity kind must be one of #{ENTITY_KINDS.join(', ')}"
    end

    def validate_er!
      unless nodes.empty? && edges.empty? && groups.empty? && events.empty? && rules.empty? && states.empty? &&
             transitions.empty? && zones.empty? && phases.empty? && crosscuts.empty?
        raise Error, 'ER diagrams accept only dedicated ER records'
      end
      raise Error, 'ER diagrams require two to six entities' unless entities.size.between?(2, 6)
      raise Error, 'ER entity IDs must be unique' unless entities.map(&:id).uniq.size == entities.size
      raise Error, 'ER diagrams allow at most one focal entity' if entities.count(&:focal) > 1
      entities.each do |item|
        raise Error, "ER entity #{item.id} requires one to eight visible fields" unless item.fields.size.between?(1, 8)
        unless item.fields.map(&:id).uniq.size == item.fields.size
          raise Error, "ER field IDs must be unique within entity #{item.id}"
        end
      end
      raise Error, 'ER diagrams require one to eight relationships' unless relationships.size.between?(1, 8)
      ids = entities.map(&:id)
      relationships.each do |item|
        raise Error, "Unknown ER entity: #{item.from}" unless ids.include?(item.from)
        raise Error, "Unknown ER entity: #{item.to}" unless ids.include?(item.to)
      end
      entities.each do |item|
        item.fields.each(&:freeze)
        item.fields.freeze
        item.freeze
      end
      entities.freeze
      relationships.each(&:freeze)
      relationships.freeze
    end
  end
end

SlimGraphR::Diagram.prepend(SlimGraphR::ERDSL)
