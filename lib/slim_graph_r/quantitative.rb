# frozen_string_literal: true
quantitative_verbose = $VERBOSE
$VERBOSE = nil
require 'bigdecimal'
$VERBOSE = quantitative_verbose
require 'date'

module SlimGraphR
  module Quantitative
    Scale = Struct.new(:min, :max, :automatic, :reference, keyword_init: true)
    Category = Struct.new(:id, :label, :value, :focal, keyword_init: true)
    Observation = Struct.new(:value, :gap, :reason, keyword_init: true)
    Series = Struct.new(:id, :label, :observations, :focal, keyword_init: true)
    Point = Struct.new(:id, :label, :x, :y, :focal, :annotate, :anonymous, keyword_init: true)

    module Value
      module_function

      def number(value, context)
        valid = value.is_a?(Integer) || value.is_a?(Float) || value.is_a?(BigDecimal)
        finite = value.is_a?(Integer) || (valid && value.finite?)
        raise Error, "#{context} must be a finite Integer, Float, or BigDecimal" unless valid && finite
        number = BigDecimal(value.to_s)
        number.zero? ? BigDecimal('0') : number
      end

      def json_number(value, context)
        unless value.is_a?(Integer) || (value.is_a?(Float) && value.finite?)
          raise Error, "#{context} must be a finite JSON number"
        end
        number = BigDecimal(value.to_s)
        number.zero? ? BigDecimal('0') : number
      end

      def text(value, context)
        raise Error, "#{context} must be a nonblank string" unless value.is_a?(String)
        clean = Text.clean(value)
        raise Error, "#{context} must be a nonblank string" if clean.strip.empty?
        raise Error, "#{context} must be trimmed" unless clean == clean.strip
        clean
      end

      def id(value, context)
        raise Error, "#{context} must be a nonblank String or Symbol" unless value.class == String || value.class == Symbol
        clean = Text.clean(value.to_s)
        raise Error, "#{context} must be a nonblank String or Symbol" if clean.strip.empty?
        raise Error, "#{context} must be trimmed" unless clean == clean.strip
        clean
      end

      def boolean(value, context)
        raise Error, "#{context} must be true or false" unless value == true || value == false
        value
      end

      def format(value, precision)
        rounded = value.round(precision, :half_even)
        text = rounded.is_a?(BigDecimal) ? rounded.to_s('F') : rounded.to_s
        text = text.sub(/\.0+\z/, '').sub(/(\.\d*?)0+\z/, '\\1')
        text == '-0' ? '0' : text
      end

      def canonical(value) = value.to_s('F')
    end

    class SeriesBuilder
      attr_reader :observations

      def initialize
        @observations = []
      end

      def point(value)
        @observations << Observation.new(value: Value.number(value, 'Line point value'), gap: false, reason: nil)
      end

      def gap(reason:)
        @observations << Observation.new(value: nil, gap: true, reason: Value.text(reason, 'Gap reason'))
      end
    end

    class Chart
      attr_reader :type, :title, :description, :style, :theme, :unit, :x_unit, :y_unit,
                  :source_note, :precision, :notation, :orientation, :categories,
                  :series_list, :points, :x_axis_kind, :x_domain, :domain,
                  :x_domain_scale, :y_domain_scale

      def initialize(type, title: 'Diagram', description: nil, unit: nil, x_unit: nil, y_unit: nil,
                     style: :editorial, theme: :light, source_note: nil, precision: 3,
                     notation: :plain, orientation: :vertical, &block)
        @type = type.to_sym
        raise Error, 'Quantitative type must be bar, line, or scatter' unless %i[bar line scatter].include?(@type)
        @title = Value.text(title, 'Title')
        @description = description.nil? ? nil : Value.text(description, 'Description')
        @source_note = source_note.nil? ? nil : Value.text(source_note, 'Source note')
        raise Error, 'precision must be an Integer from 0 through 6' unless precision.is_a?(Integer) && precision.between?(0, 6)
        @precision = precision
        @notation = notation.to_s.to_sym
        raise Error, 'notation must be :plain' unless @notation == :plain
        @style = Style.fetch(style).name
        @theme = theme.to_s.to_sym
        raise Error, 'Theme must be :light, :dark, or :auto' unless %i[light dark auto].include?(@theme)
        @unit = unit.nil? ? nil : Value.text(unit, 'Unit')
        @x_unit = x_unit.nil? ? nil : Value.text(x_unit, 'X unit')
        @y_unit = y_unit.nil? ? nil : Value.text(y_unit, 'Y unit')
        @orientation = orientation.to_s.to_sym
        @categories, @series_list, @points = [], [], []
        @declared_scale = @declared_x_scale = @declared_y_scale = nil
        @x_axis_kind = @x_domain = nil
        instance_eval(&block) if block
        validate!
        freeze_records!
        freeze
      end

      def scale(min:, max:)
        raise Error, 'scale is available only for bar and line charts' unless %i[bar line].include?(type)
        raise Error, 'scale may be declared only once' if @declared_scale
        @declared_scale = explicit_scale(min, max, 'Scale')
      end

      def x_scale(min:, max:)
        raise Error, 'x_scale is available only for scatter charts' unless type == :scatter
        raise Error, 'x_scale may be declared only once' if @declared_x_scale
        @declared_x_scale = explicit_scale(min, max, 'X scale')
      end

      def y_scale(min:, max:)
        raise Error, 'y_scale is available only for scatter charts' unless type == :scatter
        raise Error, 'y_scale may be declared only once' if @declared_y_scale
        @declared_y_scale = explicit_scale(min, max, 'Y scale')
      end

      def category(id, label, value, focal: false)
        raise Error, 'category is available only for bar charts' unless type == :bar
        @categories << Category.new(id: Value.id(id, 'Category ID'), label: Value.text(label, 'Category label'),
                                    value: Value.number(value, 'Category value'), focal: Value.boolean(focal, 'focal'))
      end

      def x_axis(kind, domain:)
        raise Error, 'x_axis is available only for line charts' unless type == :line
        raise Error, 'x_axis may be declared only once' if @x_axis_kind
        @x_axis_kind = kind.to_s.to_sym
        raise Error, 'x_axis kind must be :time or :ordinal' unless %i[time ordinal].include?(@x_axis_kind)
        raise Error, 'x_axis domain must contain 3–24 strings' unless domain.is_a?(Array) && domain.size.between?(3, 24)
        @x_domain = domain.map { |item| Value.text(item, 'X domain position') }
      end

      def series(id, label, focal: false, &block)
        raise Error, 'series is available only for line charts' unless type == :line
        raise Error, 'series requires a block' unless block
        builder = SeriesBuilder.new
        builder.instance_eval(&block)
        @series_list << Series.new(id: Value.id(id, 'Series ID'), label: Value.text(label, 'Series label'),
                                  observations: builder.observations, focal: Value.boolean(focal, 'focal'))
      end

      def point(id, label, x:, y:, focal: false, annotate: false)
        raise Error, 'point is available only for scatter charts' unless type == :scatter
        @points << Point.new(id: Value.id(id, 'Point ID'), label: Value.text(label, 'Point label'),
                            x: Value.number(x, 'Point x'), y: Value.number(y, 'Point y'),
                            focal: Value.boolean(focal, 'focal'), annotate: Value.boolean(annotate, 'annotate'), anonymous: false)
      end

      def anonymous_point(x:, y:)
        raise Error, 'anonymous_point is available only for scatter charts' unless type == :scatter
        @points << Point.new(id: nil, label: nil, x: Value.number(x, 'Anonymous point x'), y: Value.number(y, 'Anonymous point y'),
                             focal: false, annotate: false, anonymous: true)
      end

      def style_profile = Style.fetch(style)

      def auto_reference? = domain&.reference == true

      def to_svg(id: nil) = QuantitativeSVG.new(self, id: id).render

      def to_html
        "<!doctype html><html><head><meta charset=\"utf-8\"><title>#{CGI.escapeHTML(title)}</title></head><body style=\"margin:0;background:#{style_profile.public_send(theme == :dark ? :dark : :light)[:paper]}\">#{to_svg}</body></html>"
      end

      def with(style: @style, theme: @theme, **extra)
        raise Error, 'Quantitative charts do not accept a timeline scale override' unless extra.empty?
        copy = dup
        copy.instance_variable_set(:@style, Style.fetch(style).name)
        mode = theme.to_s.to_sym
        raise Error, 'Theme must be :light, :dark, or :auto' unless %i[light dark auto].include?(mode)
        copy.instance_variable_set(:@theme, mode)
        copy.freeze
      end

      def accessible_description
        return description if description
        scale_text = if type == :scatter
          "linear x domain #{Value.format(x_domain_scale.min, precision)} to #{Value.format(x_domain_scale.max, precision)} #{x_unit}; linear y domain #{Value.format(y_domain_scale.min, precision)} to #{Value.format(y_domain_scale.max, precision)} #{y_unit}"
        else
          prefix = auto_reference? ? 'AUTO REFERENCE DOMAIN ' : 'linear domain '
          "#{prefix}#{Value.format(domain.min, precision)} to #{Value.format(domain.max, precision)} #{unit}"
        end
        data = case type
               when :bar
                 categories.map { |item| "#{item.label}: #{Value.format(item.value, precision)} #{unit}#{item.value.zero? ? ' (zero; no rectangle)' : ''}#{item.focal ? ' (focal)' : ''}" }.join('; ')
               when :line
                 spacing = x_axis_kind == :ordinal ? 'Spacing is ordinal, not elapsed time.' : 'X spacing is elapsed Gregorian days.'
                 details = series_list.map do |item|
                   values = item.observations.each_with_index.map do |obs, index|
                     obs.gap ? "#{x_domain[index]}: gap (#{obs.reason})" : "#{x_domain[index]}: #{Value.format(obs.value, precision)} #{unit}"
                   end.join(', ')
                   "#{item.label}#{item.focal ? ' (focal)' : ''}: #{values}"
                 end.join('; ')
                 "#{spacing} #{details}"
               when :scatter
                 named = points.reject(&:anonymous).map { |item| "#{item.label}#{item.focal ? ' (focal)' : ''}: x #{Value.format(item.x, precision)} #{x_unit}, y #{Value.format(item.y, precision)} #{y_unit}" }
                 anonymous = points.select(&:anonymous)
                 if anonymous.any?
                   xs, ys = anonymous.map(&:x).minmax, anonymous.map(&:y).minmax
                   named << "#{anonymous.size} anonymous marks: x #{Value.format(xs[0], precision)} to #{Value.format(xs[1], precision)} #{x_unit}, y #{Value.format(ys[0], precision)} to #{Value.format(ys[1], precision)} #{y_unit}"
                 end
                 named.join('; ')
               end
        source = source_note ? " Source: #{source_note}." : ''
        "#{type} chart. #{scale_text}. #{data}.#{source}"
      end

      def ==(other)
        other.class == self.class && state == other.send(:state)
      end
      alias eql? ==

      protected

      def state
        [type, title, description, style, theme, unit, x_unit, y_unit, source_note, precision, notation,
         orientation, categories, series_list, points, x_axis_kind, x_domain, domain, x_domain_scale, y_domain_scale]
      end

      private

      def explicit_scale(min, max, context)
        lo = Value.number(min, "#{context} min")
        hi = Value.number(max, "#{context} max")
        raise Error, "#{context} min must be less than max" unless lo < hi
        Scale.new(min: lo, max: hi, automatic: false, reference: false)
      end

      def validate!
        case type
        when :bar then validate_bar!
        when :line then validate_line!
        when :scatter then validate_scatter!
        end
      end

      def validate_bar!
        raise Error, 'Bar charts require a unit' unless unit
        raise Error, 'Bar orientation must be :vertical or :horizontal' unless %i[vertical horizontal].include?(orientation)
        raise Error, 'Bar charts require 2–12 categories' unless categories.size.between?(2, 12)
        validate_unique!(categories, 'Category')
        validate_focal!(categories)
        @domain = @declared_scale || automatic_scale(categories.map(&:value))
        ensure_contains!(@domain, categories.map(&:value), 'Bar scale')
        raise Error, 'Bar scale must contain zero' unless @domain.min <= 0 && @domain.max >= 0
      end

      def validate_line!
        raise Error, 'Line charts require a unit' unless unit
        raise Error, 'Line charts require x_axis' unless x_axis_kind
        raise Error, 'Line charts require 1–4 series' unless series_list.size.between?(1, 4)
        validate_unique!(series_list, 'Series')
        validate_focal!(series_list)
        validate_x_domain!
        series_list.each do |item|
          unless item.observations.size == x_domain.size
            raise Error, "Every line series must have exactly one observation or explicit gap at each x position"
          end
        end
        values = series_list.flat_map(&:observations).reject(&:gap).map(&:value)
        raise Error, 'Line charts require at least one ordinary point' if values.empty?
        @domain = @declared_scale || automatic_scale(values)
        ensure_contains!(@domain, values, 'Line scale')
      end

      def validate_x_domain!
        raise Error, 'X domain positions must be unique' unless x_domain.uniq.size == x_domain.size
        return unless x_axis_kind == :time
        dates = x_domain.map do |value|
          date = Date.iso8601(value)
          raise ArgumentError unless date.strftime('%Y-%m-%d') == value
          date
        rescue Date::Error, ArgumentError
          raise Error, 'Time x_axis accepts only complete Gregorian YYYY-MM-DD positions'
        end
        raise Error, 'Time x_axis positions must be strictly ascending in author order' unless dates.each_cons(2).all? { |a, b| a < b }
      end

      def validate_scatter!
        raise Error, 'Scatter charts require x_unit and y_unit' unless x_unit && y_unit
        raise Error, 'Scatter charts require explicit x_scale and y_scale' unless @declared_x_scale && @declared_y_scale
        raise Error, 'Scatter charts require 2–30 complete points' unless points.size.between?(2, 30)
        named = points.reject(&:anonymous)
        validate_unique!(named, 'Point')
        validate_focal!(named)
        raise Error, 'Scatter charts allow at most three annotations' if points.count(&:annotate) > 3
        ensure_contains!(@declared_x_scale, points.map(&:x), 'X scale')
        ensure_contains!(@declared_y_scale, points.map(&:y), 'Y scale')
        @x_domain_scale, @y_domain_scale = @declared_x_scale, @declared_y_scale
      end

      def validate_unique!(records, context)
        raise Error, "#{context} IDs must be unique" unless records.map { |item| item.id.unicode_normalize(:nfc) }.uniq.size == records.size
        raise Error, "#{context} labels must be unique" unless records.map { |item| item.label.unicode_normalize(:nfc) }.uniq.size == records.size
      end

      def validate_focal!(records)
        raise Error, 'A quantitative chart allows at most one focal item' if records.count(&:focal) > 1
      end

      def automatic_scale(values)
        lo, hi = values.minmax
        if lo == hi
          if lo.zero?
            Scale.new(min: BigDecimal('-1'), max: BigDecimal('1'), automatic: true, reference: true)
          elsif lo.positive?
            Scale.new(min: BigDecimal('0'), max: lo + 1, automatic: true, reference: true)
          else
            Scale.new(min: lo - 1, max: BigDecimal('0'), automatic: true, reference: true)
          end
        else
          Scale.new(min: [lo, BigDecimal('0')].min, max: [hi, BigDecimal('0')].max, automatic: true, reference: false)
        end
      end

      def ensure_contains!(scale, values, context)
        return if values.all? { |value| value >= scale.min && value <= scale.max }
        raise Error, "#{context} must contain every value"
      end

      def freeze_records!
        [@domain, @x_domain_scale, @y_domain_scale].compact.each(&:freeze)
        categories.each(&:freeze)
        series_list.each do |item|
          item.observations.each(&:freeze)
          item.observations.freeze
          item.freeze
        end
        points.each(&:freeze)
        [categories, series_list, points].each(&:freeze)
        @x_domain&.freeze
      end
    end
  end
end
