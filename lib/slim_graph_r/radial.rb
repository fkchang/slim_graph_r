# frozen_string_literal: true

module SlimGraphR
  module Radial
    Scale = Quantitative::Scale
    Category = Struct.new(:id, :label, :value, :focal, keyword_init: true)
    Criterion = Struct.new(:id, :label, keyword_init: true)
    Entity = Struct.new(:id, :label, :values, :focal, keyword_init: true)

    class Chart
      attr_reader :type, :title, :description, :style, :theme, :unit, :source_note,
                  :precision, :notation, :scale_domain, :categories, :criteria, :entities

      def initialize(type, title: 'Diagram', description: nil, unit: nil, style: :editorial,
                     theme: :light, source_note: nil, precision: 3, notation: :plain, &block)
        @type = type.to_s.to_sym
        raise Error, 'Radial type must be polar or radar' unless %i[polar radar].include?(@type)
        @title = Quantitative::Value.text(title, 'Title')
        @description = description.nil? ? nil : Quantitative::Value.text(description, 'Description')
        @unit = unit.nil? ? nil : Quantitative::Value.text(unit, 'Unit')
        @source_note = source_note.nil? ? nil : Quantitative::Value.text(source_note, 'Source note')
        raise Error, 'precision must be an Integer from 0 through 6' unless precision.is_a?(Integer) && precision.between?(0, 6)
        @precision = precision
        @notation = notation.to_s.to_sym
        raise Error, 'notation must be :plain' unless @notation == :plain
        @style = Style.fetch(style).name
        @theme = theme.to_s.to_sym
        raise Error, 'Theme must be :light, :dark, or :auto' unless %i[light dark auto].include?(@theme)
        @categories, @criteria, @entities = [], [], []
        @declared_scale = nil
        instance_eval(&block) if block
        validate!
        freeze_records!
        freeze
      end

      def scale(min:, max:)
        raise Error, 'scale may be declared only once' if @declared_scale
        low = Quantitative::Value.number(min, 'Scale min')
        high = Quantitative::Value.number(max, 'Scale max')
        raise Error, 'Radial scale min must be exactly 0' unless low.zero?
        raise Error, 'Radial scale max must be finite and positive' unless high.positive?
        @declared_scale = Scale.new(min: low, max: high, automatic: false, reference: false)
      end

      def category(id, label, value, focal: false)
        raise Error, 'category is available only for polar charts' unless type == :polar
        @categories << Category.new(id: Quantitative::Value.id(id, 'Category ID'),
          label: Quantitative::Value.text(label, 'Category label'),
          value: Quantitative::Value.number(value, 'Category value'),
          focal: Quantitative::Value.boolean(focal, 'focal'))
      end

      def criterion(id, label)
        raise Error, 'criterion is available only for radar charts' unless type == :radar
        @criteria << Criterion.new(id: Quantitative::Value.id(id, 'Criterion ID'),
          label: Quantitative::Value.text(label, 'Criterion label'))
      end

      def entity(id, label, values:, focal: false)
        raise Error, 'entity is available only for radar charts' unless type == :radar
        raise Error, 'Entity values must be a Hash' unless values.class == Hash
        normalized = values.each_with_object({}) do |(key, value), result|
          identifier = Quantitative::Value.id(key, 'Entity value criterion ID')
          raise Error, "Entity values contain duplicate criterion #{identifier}" if result.key?(identifier)
          result[identifier] = Quantitative::Value.number(value, "Entity value for #{identifier}")
        end
        @entities << Entity.new(id: Quantitative::Value.id(id, 'Entity ID'),
          label: Quantitative::Value.text(label, 'Entity label'), values: normalized,
          focal: Quantitative::Value.boolean(focal, 'focal'))
      end

      def style_profile = Style.fetch(style)
      def domain = scale_domain
      def to_svg(id: nil) = RadialSVG.new(self, id: id).render

      def to_html
        palette = style_profile.public_send(theme == :dark ? :dark : :light)
        "<!doctype html><html><head><meta charset=\"utf-8\"><title>#{CGI.escapeHTML(title)}</title></head><body style=\"margin:0;background:#{palette[:paper]}\">#{to_svg}</body></html>"
      end

      def with(style: @style, theme: @theme, **extra)
        raise Error, 'Radial charts do not accept a timeline scale override' unless extra.empty?
        copy = dup
        copy.instance_variable_set(:@style, Style.fetch(style).name)
        mode = theme.to_s.to_sym
        raise Error, 'Theme must be :light, :dark, or :auto' unless %i[light dark auto].include?(mode)
        copy.instance_variable_set(:@theme, mode)
        copy.freeze
      end

      def accessible_description
        return description if description
        range = "linear 0 to #{format_value(scale_domain.max)} #{unit}"
        detail = if type == :polar
          order = categories.map do |item|
            suffix = []
            suffix << 'zero; no ray or marker' if item.value.zero?
            suffix << 'focal' if item.focal
            "#{item.label}: #{format_value(item.value)} #{unit}#{suffix.empty? ? '' : " (#{suffix.join('; ')})"}"
          end.join('; ')
          "Clockwise category order: #{order}; ray length/radius encodes value; area encodes nothing."
        else
          rows = entities.map do |entity|
            values = criteria.map { |criterion| "#{criterion.label} #{format_value(entity.values.fetch(criterion.id))}" }.join(', ')
            "#{entity.label}#{entity.focal ? ' (focal)' : ''}: #{values}"
          end.join('; ')
          "Criterion order: #{criteria.map(&:label).join(', ')}. #{rows}. Vertex radius encodes the common score; polygon area encodes nothing."
        end
        source = source_note ? " Source: #{source_note}." : ''
        "#{type} chart. #{range}. #{detail}#{source}"
      end

      def ==(other) = other.class == self.class && state == other.send(:state)
      alias eql? ==

      protected

      def state
        [type, title, description, style, theme, unit, source_note, precision, notation,
         scale_domain, categories, criteria, entities]
      end

      private

      def validate!
        raise Error, "#{type.to_s.capitalize} charts require a unit" unless unit
        raise Error, "#{type.to_s.capitalize} charts require an explicit scale" unless @declared_scale
        @scale_domain = @declared_scale
        type == :polar ? validate_polar! : validate_radar!
      end

      def validate_polar!
        raise Error, 'Polar charts require 4–8 categories' unless categories.size.between?(4, 8)
        validate_unique!(categories, 'Category')
        validate_focal!(categories, 'Polar chart')
        ensure_values_in_range!(categories.map(&:value), 'Polar')
      end

      def validate_radar!
        raise Error, 'Radar charts require 3–5 criteria' unless criteria.size.between?(3, 5)
        raise Error, 'Radar charts require 2–5 entities' unless entities.size.between?(2, 5)
        validate_unique!(criteria, 'Criterion')
        validate_unique!(entities, 'Entity')
        validate_focal!(entities, 'Radar chart')
        criterion_ids = criteria.map(&:id)
        entities.each do |entity|
          unless entity.values.keys.sort == criterion_ids.sort
            raise Error, "Every radar entity must provide values for exactly the declared criteria"
          end
          entity.values = criterion_ids.to_h { |id| [id, entity.values.fetch(id)] }
          ensure_values_in_range!(entity.values.values, "Radar entity #{entity.id}")
        end
      end

      def validate_unique!(records, context)
        ids = records.map { |item| item.id.unicode_normalize(:nfc) }
        labels = records.map { |item| item.label.unicode_normalize(:nfc) }
        raise Error, "#{context} IDs must be unique" unless ids.uniq.size == ids.size
        raise Error, "#{context} labels must be unique" unless labels.uniq.size == labels.size
      end

      def validate_focal!(records, context)
        raise Error, "#{context} allows at most one focal item" if records.count(&:focal) > 1
      end

      def ensure_values_in_range!(values, context)
        unless values.all? { |value| value >= 0 && value <= scale_domain.max }
          raise Error, "#{context} values must be within the common scale 0 through #{Quantitative::Value.canonical(scale_domain.max)}"
        end
      end

      def format_value(value) = Quantitative::Value.format(value, precision)

      def freeze_records!
        scale_domain.freeze
        categories.each(&:freeze)
        criteria.each(&:freeze)
        entities.each do |entity|
          entity.values.freeze
          entity.freeze
        end
        [categories, criteria, entities].each(&:freeze)
      end
    end
  end
end
