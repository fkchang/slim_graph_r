# frozen_string_literal: true
module SlimGraphR
  FishboneEffect = Struct.new(:label, keyword_init: true)
  FishboneCategory = Struct.new(:id, :label, :side, :factors, :confirmed, keyword_init: true)

  module FishboneDSL
    attr_reader :fishbone_effect, :fishbone_categories

    def initialize(...)
      @fishbone_effect = nil
      @fishbone_categories = []
      @fishbone_factor_scope = nil
      super
    end

    def effect(label)
      raise Error, 'effect is available only in a fishbone diagram' unless type == :fishbone
      raise Error, 'A fishbone requires exactly one effect' if @fishbone_effect
      @fishbone_effect = FishboneEffect.new(label: fishbone_text(label, 'Fishbone effect'))
    end

    def category(id, label, side:, confirmed: false, &block)
      raise Error, 'category is available only in a fishbone diagram' unless type == :fishbone
      clean_side = side.to_sym if side.respond_to?(:to_sym)
      raise Error, 'Fishbone category side must be :above or :below' unless %i[above below].include?(clean_side)
      factors = []
      previous = @fishbone_factor_scope
      @fishbone_factor_scope = factors
      instance_eval(&block) if block
      record = FishboneCategory.new(id: fishbone_text(id, 'Fishbone category ID'),
                                    label: fishbone_text(label, 'Fishbone category label'),
                                    side: clean_side, factors: factors,
                                    confirmed: Quantitative::Value.boolean(confirmed, 'Fishbone category confirmed'))
      @fishbone_categories << record
      record
    ensure
      @fishbone_factor_scope = previous
    end

    def factor(label)
      raise Error, 'factor is available only inside a fishbone category block' unless type == :fishbone && @fishbone_factor_scope
      @fishbone_factor_scope << fishbone_text(label, 'Fishbone factor')
    end

    def node(...)
      raise Error, 'Fishbone diagrams use dedicated effect, category, and factor records' if type == :fishbone
      super
    end

    def edge(...)
      raise Error, 'Fishbone diagrams use dedicated effect, category, and factor records' if type == :fishbone
      super
    end

    def flow(...)
      raise Error, 'Fishbone diagrams use dedicated effect, category, and factor records' if type == :fishbone
      super
    end

    def group(...)
      raise Error, 'Fishbone diagrams use dedicated effect, category, and factor records' if type == :fishbone
      super
    end

    private

    def fishbone_text(value, name)
      raise Error, "#{name} must be a String or Symbol" unless value.is_a?(String) || value.is_a?(Symbol)
      clean = Text.clean(value)
      raise Error, "#{name} must not be blank" if clean.strip.empty?
      clean
    end

    def validate_fishbone!
      unless nodes.empty? && edges.empty? && groups.empty? && events.empty? && rules.empty? && states.empty? && transitions.empty? &&
             zones.empty? && phases.empty? && crosscuts.empty? && sources.empty? && components.empty? && connections.empty?
        raise Error, 'Fishbone diagrams accept only dedicated effect, category, and factor records'
      end
      raise Error, 'A fishbone requires exactly one effect' unless fishbone_effect
      raise Error, 'A fishbone requires two to five categories' unless fishbone_categories.size.between?(2, 5)
      raise Error, 'Fishbone category IDs must be unique' unless fishbone_categories.map(&:id).uniq.size == fishbone_categories.size
      unless %i[above below].all? { |side| fishbone_categories.any? { |item| item.side == side } }
        raise Error, 'A fishbone requires at least one category on each side'
      end
      if fishbone_categories.group_by(&:side).values.any? { |items| items.size > 3 }
        raise Error, 'A fishbone allows at most three categories per side'
      end
      unless fishbone_categories.all? { |item| item.factors.size.between?(1, 3) }
        raise Error, 'Each fishbone category requires one to three factors'
      end
      raise Error, 'A fishbone allows at most 18 factors' if fishbone_categories.sum { |item| item.factors.size } > 18
      raise Error, 'A fishbone allows at most one confirmed root category' if fishbone_categories.count(&:confirmed) > 1
      fishbone_effect.freeze
      fishbone_categories.each { |item| item.factors.each(&:freeze); item.factors.freeze; item.freeze }
      fishbone_categories.freeze
    end
  end
end

SlimGraphR::Diagram.prepend(SlimGraphR::FishboneDSL)
