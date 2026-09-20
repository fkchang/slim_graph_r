# frozen_string_literal: true
module SlimGraphR
  QuadrantAxis = Struct.new(:low, :high, keyword_init: true)
  QuadrantItem = Struct.new(:id, :label, :x, :y, :focal, keyword_init: true)
  QuadrantRegion = Struct.new(:position, :label, keyword_init: true)

  module QuadrantDSL
    DEAD_BAND = 0.08

    attr_reader :horizontal_axis_record, :vertical_axis_record, :items, :quadrant_regions

    def initialize(...)
      @horizontal_axis_record = @vertical_axis_record = nil
      @items = []
      @quadrant_regions = []
      super
    end

    def horizontal_axis(low:, high:)
      raise Error, 'horizontal_axis is available only in a quadrant diagram' unless type == :quadrant
      raise Error, 'A quadrant accepts exactly one horizontal_axis declaration' if @horizontal_axis_record
      @horizontal_axis_record = QuadrantAxis.new(low: quadrant_text(low, 'Horizontal-axis low phrase'),
                                                  high: quadrant_text(high, 'Horizontal-axis high phrase'))
    end

    def vertical_axis(low:, high:)
      raise Error, 'vertical_axis is available only in a quadrant diagram' unless type == :quadrant
      raise Error, 'A quadrant accepts exactly one vertical_axis declaration' if @vertical_axis_record
      @vertical_axis_record = QuadrantAxis.new(low: quadrant_text(low, 'Vertical-axis low phrase'),
                                                high: quadrant_text(high, 'Vertical-axis high phrase'))
    end

    def item(id, label, x:, y:, focal: false)
      raise Error, 'item is available only in a quadrant diagram' unless type == :quadrant
      raise Error, 'Quadrant item focal must be true or false' unless focal == true || focal == false
      @items << QuadrantItem.new(id: quadrant_text(id, 'Quadrant item ID'),
                                 label: quadrant_text(label, 'Quadrant item label'),
                                 x: quadrant_coordinate(x, 'x'), y: quadrant_coordinate(y, 'y'), focal: focal)
    end

    def region(position, label)
      raise Error, 'region is available only in a quadrant diagram' unless type == :quadrant
      position = position.to_sym if position.respond_to?(:to_sym)
      unless %i[upper_left upper_right lower_left lower_right].include?(position)
        raise Error, 'Quadrant region position must be :upper_left, :upper_right, :lower_left, or :lower_right'
      end
      @quadrant_regions << QuadrantRegion.new(position: position, label: quadrant_text(label, 'Quadrant region label'))
    end

    def node(...)
      raise Error, 'Quadrant diagrams use dedicated item records' if type == :quadrant
      super
    end

    def edge(...)
      raise Error, 'Quadrant diagrams do not accept graph edges' if type == :quadrant
      super
    end

    def flow(...)
      raise Error, 'Quadrant diagrams do not accept graph flows' if type == :quadrant
      super
    end

    def group(...)
      raise Error, 'Quadrant diagrams do not accept generic groups' if type == :quadrant
      super
    end

    private

    def quadrant_text(value, name)
      raise Error, "#{name} must be a String or Symbol" unless value.is_a?(String) || value.is_a?(Symbol)
      clean = Text.clean(value)
      raise Error, "#{name} must not be blank" if clean.strip.empty?
      clean
    end

    def quadrant_coordinate(value, name)
      unless (value.is_a?(Integer) || value.is_a?(Float)) && value.finite?
        raise Error, "Quadrant item #{name} must be a real finite number"
      end
      coordinate = value.to_f
      raise Error, "Quadrant item #{name} must be in [-1, 1]" unless coordinate.between?(-1.0, 1.0)
      if coordinate.abs < DEAD_BAND
        raise Error, "Quadrant item #{name} must stay outside the central safety band (absolute value at least #{DEAD_BAND})"
      end
      coordinate
    end

    def validate_quadrant!
      unless nodes.empty? && edges.empty? && groups.empty? && events.empty? && rules.empty? && states.empty? &&
             transitions.empty? && zones.empty? && phases.empty? && crosscuts.empty?
        raise Error, 'Quadrant diagrams accept only dedicated axes and item records'
      end
      raise Error, 'A quadrant requires one horizontal_axis declaration' unless horizontal_axis_record
      raise Error, 'A quadrant requires one vertical_axis declaration' unless vertical_axis_record
      raise Error, 'A quadrant requires two to twelve items' unless items.size.between?(2, 12)
      raise Error, 'Quadrant item IDs must be unique' unless items.map(&:id).uniq.size == items.size
      raise Error, 'A quadrant allows at most one focal item' if items.count(&:focal) > 1
      raise Error, 'Quadrant region positions must be unique' unless quadrant_regions.map(&:position).uniq.size == quadrant_regions.size
      horizontal_axis_record.freeze
      vertical_axis_record.freeze
      items.each(&:freeze)
      items.freeze
      quadrant_regions.each(&:freeze)
      quadrant_regions.freeze
    end
  end
end

SlimGraphR::Diagram.prepend(SlimGraphR::QuadrantDSL)
