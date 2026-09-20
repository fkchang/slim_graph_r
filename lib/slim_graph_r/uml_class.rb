# frozen_string_literal: true
module SlimGraphR
  UMLClassRecord = Struct.new(:id, :label, :kind, :focal, :attributes, :operations, keyword_init: true)
  UMLRelation = Struct.new(:from, :to, :kind, :label, :owner, :from_multiplicity, :to_multiplicity, keyword_init: true)

  module UMLClassDSL
    UML_UNSET = Object.new.freeze
    UML_KINDS = %i[class abstract_class interface].freeze
    UML_RELATION_KINDS = %i[inheritance realization composition aggregation association dependency].freeze
    UML_MULTIPLICITIES = %w[1 0..* 1..*].freeze

    attr_reader :classes, :relations

    def initialize(...)
      @classes = []
      @relations = []
      @current_uml_class = nil
      super
    end

    def class_type(id, label = UML_UNSET, focal: false, **options, &block)
      add_uml_class(:class, id, label, focal, options, &block)
    end

    def abstract_class(id, label = UML_UNSET, focal: false, **options, &block)
      add_uml_class(:abstract_class, id, label, focal, options, &block)
    end

    def interface(id, label = UML_UNSET, focal: false, **options, &block)
      add_uml_class(:interface, id, label, focal, options, &block)
    end

    def attribute(value)
      raise Error, 'attribute is available only inside a UML class declaration' unless type == :uml_class && @current_uml_class
      @current_uml_class.attributes << uml_text(value, 'UML attribute')
    end

    def operation(value = UML_UNSET, *arguments, **options, &block)
      return super(value, *arguments, **options, &block) unless type == :uml_class
      raise Error, 'operation is available only inside a UML class declaration' unless @current_uml_class
      unless !value.equal?(UML_UNSET) && arguments.empty? && options.empty? && !block
        raise Error, 'A UML operation accepts exactly one literal member string'
      end
      @current_uml_class.operations << uml_text(value, 'UML operation')
    end

    def relation(from, to, kind:, label: UML_UNSET, owner: UML_UNSET, from_multiplicity: UML_UNSET, to_multiplicity: UML_UNSET, **options)
      raise Error, 'relation is available only in a UML class diagram' unless type == :uml_class
      raise Error, 'A UML relation must be declared outside class blocks' if @current_uml_class
      raise Error, "Unknown UML relation options: #{options.keys.join(', ')}" unless options.empty?
      relation_kind = kind.to_sym
      unless UML_RELATION_KINDS.include?(relation_kind)
        raise Error, "UML relation kind must be one of #{UML_RELATION_KINDS.join(', ')}"
      end
      from_id = uml_text(from, 'UML relation source')
      to_id = uml_text(to, 'UML relation target')
      raise Error, 'UML relations require distinct endpoints' if from_id == to_id
      relation_label = label.equal?(UML_UNSET) ? nil : uml_text(label, 'UML relation label')
      owns = %i[composition aggregation].include?(relation_kind)
      association = relation_kind == :association
      if owns
        raise Error, 'Composition and aggregation require an explicit owner endpoint' if owner.equal?(UML_UNSET)
        owner_id = uml_text(owner, 'UML relation owner')
        raise Error, 'UML relation owner must be the source or target endpoint' unless [from_id, to_id].include?(owner_id)
      elsif !owner.equal?(UML_UNSET)
        raise Error, 'owner is accepted only for composition and aggregation'
      end
      if association
        if from_multiplicity.equal?(UML_UNSET) || to_multiplicity.equal?(UML_UNSET)
          raise Error, 'Association requires both from and to multiplicities'
        end
        from_value = clean_uml_multiplicity(from_multiplicity, 'from')
        to_value = clean_uml_multiplicity(to_multiplicity, 'to')
      elsif !from_multiplicity.equal?(UML_UNSET) || !to_multiplicity.equal?(UML_UNSET)
        raise Error, 'Multiplicities are accepted only for association relations'
      end
      item = UMLRelation.new(from: from_id, to: to_id, kind: relation_kind, label: relation_label, owner: owner_id,
                             from_multiplicity: from_value, to_multiplicity: to_value)
      raise Error, 'Duplicate UML relation' if @relations.any? { |existing| existing.to_h == item.to_h }
      @relations << item
    rescue NoMethodError
      raise Error, "UML relation kind must be one of #{UML_RELATION_KINDS.join(', ')}"
    end

    def node(...)
      raise Error, 'UML class diagrams use dedicated UML class records' if type == :uml_class
      super
    end

    def edge(...)
      raise Error, 'UML class diagrams use dedicated UML relations' if type == :uml_class
      super
    end

    def flow(...)
      raise Error, 'UML class diagrams use dedicated UML relations' if type == :uml_class
      super
    end

    def group(...)
      raise Error, 'UML class diagrams do not accept generic groups' if type == :uml_class
      super
    end

    private

    def add_uml_class(kind, id, label, focal, options, &block)
      raise Error, 'UML class constructors are available only in a UML class diagram' unless type == :uml_class
      raise Error, 'UML classes cannot be nested' if @current_uml_class
      raise Error, "Unknown UML class options: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'UML class label is required and must not be blank' if label.equal?(UML_UNSET)
      raise Error, 'UML class focal must be true or false' unless focal == true || focal == false
      item = UMLClassRecord.new(id: uml_text(id, 'UML class ID'), label: uml_text(label, 'UML class label'),
                                kind: kind, focal: focal, attributes: [], operations: [])
      @classes << item
      previous = @current_uml_class
      @current_uml_class = item
      instance_eval(&block) if block
      item
    rescue Exception
      @classes.delete(item) if defined?(item) && item
      raise
    ensure
      @current_uml_class = previous if defined?(previous)
    end

    def uml_text(value, name)
      raise Error, "#{name} must be a String or Symbol" unless value.is_a?(String) || value.is_a?(Symbol)
      clean = Text.clean(value)
      raise Error, "#{name} is required and must not be blank" if clean.strip.empty?
      clean
    end

    def clean_uml_multiplicity(value, endpoint)
      clean = uml_text(value, "Association #{endpoint} multiplicity")
      unless UML_MULTIPLICITIES.include?(clean)
        raise Error, "Association #{endpoint} multiplicity must be one of #{UML_MULTIPLICITIES.join(', ')}"
      end
      clean
    end

    def validate_uml_class!
      unless nodes.empty? && edges.empty? && groups.empty? && events.empty? && rules.empty? && states.empty? &&
             transitions.empty? && zones.empty? && phases.empty? && crosscuts.empty?
        raise Error, 'UML class diagrams accept only dedicated UML class records'
      end
      raise Error, 'UML class diagrams require two to seven classes' unless classes.size.between?(2, 7)
      raise Error, 'UML class IDs must be unique' unless classes.map(&:id).uniq.size == classes.size
      raise Error, 'A UML class diagram allows at most one focal class' if classes.count(&:focal) > 1
      classes.each do |item|
        raise Error, "UML class #{item.id} allows at most five attributes" if item.attributes.size > 5
        raise Error, "UML class #{item.id} allows at most five operations" if item.operations.size > 5
        raise Error, "UML class #{item.id} has duplicate attributes" unless item.attributes.uniq.size == item.attributes.size
        raise Error, "UML class #{item.id} has duplicate operations" unless item.operations.uniq.size == item.operations.size
      end
      raise Error, 'UML class diagrams require one to eight relations' unless relations.size.between?(1, 8)
      relations.each do |item|
        raise Error, "Unknown UML relation source: #{item.from}" unless classes.any? { |klass| klass.id == item.from }
        raise Error, "Unknown UML relation target: #{item.to}" unless classes.any? { |klass| klass.id == item.to }
      end
      classes.each do |item|
        item.attributes.each(&:freeze)
        item.operations.each(&:freeze)
        item.attributes.freeze
        item.operations.freeze
        item.freeze
      end
      classes.freeze
      relations.each(&:freeze)
      relations.freeze
    end
  end
end

SlimGraphR::Diagram.prepend(SlimGraphR::UMLClassDSL)
