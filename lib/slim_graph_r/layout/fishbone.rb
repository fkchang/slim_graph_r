# frozen_string_literal: true
module SlimGraphR
  module Layout
    FishboneBox = Struct.new(:record, :rect, :lines, keyword_init: true)
    FishboneBone = Struct.new(:record, :attach_x, :attach_y, :far_x, :far_y, :slot, keyword_init: true)
    FishboneTick = Struct.new(:category_id, :factor, :start_x, :start_y, :end_x, :end_y, :label_x, :label_y, :label_rect, keyword_init: true)
    FishboneScene = Struct.new(:width, :height, :head_x, :center_y, :spine_start_x, :spine_end_x,
                               :effect_box, :effect_text_bounds, :category_boxes, :bones, :ticks, :text_bounds, keyword_init: true)

    class Fishbone
      BASE_WIDTH = 1240.0
      EXPANDED_WIDTH = 1400.0
      WIDE_LABEL_WIDTH = 1600.0
      HEIGHT = 640.0
      HEAD_X = 1000.0
      CENTER_Y = 316.0
      EFFECT_WIDTH = 200.0
      EFFECT_HEIGHT = 112.0
      CATEGORY_HEIGHT = 32.0
      CATEGORY_MIN_WIDTH = 96.0
      CATEGORY_MAX_WIDTH = 176.0
      BONE_DX = 96.0
      BONE_DY = BONE_DX * Math.sqrt(3)
      FACTOR_TICK = 32.0
      EFFECT_TEXT_SIZE = 14
      CATEGORY_TEXT_SIZE = 12
      FACTOR_TEXT_SIZE = 12
      SIDE_OFFSETS = { above: [280.0, 560.0, 840.0], below: [400.0, 680.0, 920.0] }.freeze
      FACTOR_FRACTIONS = { 1 => [0.46], 2 => [0.32, 0.64], 3 => [0.24, 0.48, 0.72] }.freeze

      def initialize(diagram) = @d = diagram

      def call
        expanded = @d.fishbone_categories.count { |item| item.side == :below } == 3
        wide_labels = @d.fishbone_categories.flat_map(&:factors).any? { |factor| Text.width(factor, FACTOR_TEXT_SIZE, font: :mono) > 184 }
        width = wide_labels ? WIDE_LABEL_WIDTH : (expanded ? EXPANDED_WIDTH : BASE_WIDTH)
        head_x = wide_labels ? 1360.0 : HEAD_X + (expanded ? 160.0 : 0.0)
        effect_lines = Text.wrap(@d.fishbone_effect.label, EFFECT_WIDTH - 32, EFFECT_TEXT_SIZE)
        if effect_lines.size > 4
          raise LayoutError, 'Fishbone effect cannot fit its 200px head; shorten the effect or widen/split the diagram'
        end
        effect_rect = [head_x, CENTER_Y - EFFECT_HEIGHT / 2, head_x + EFFECT_WIDTH, CENTER_Y + EFFECT_HEIGHT / 2].freeze
        effect_box = FishboneBox.new(record: @d.fishbone_effect, rect: effect_rect, lines: effect_lines.freeze).freeze
        side_slots = Hash.new(0)
        bones = []
        boxes = []
        ticks = []
        text_bounds = []
        effect_text_bounds = line_bounds(effect_lines, head_x + EFFECT_WIDTH / 2, CENTER_Y, EFFECT_TEXT_SIZE,
                                         EFFECT_WIDTH - 32, centered: true).freeze
        text_bounds.concat(effect_text_bounds)

        @d.fishbone_categories.each do |record|
          slot = side_slots[record.side]
          side_slots[record.side] += 1
          attach_x = head_x - SIDE_OFFSETS.fetch(record.side).fetch(slot)
          far_x = attach_x - BONE_DX
          far_y = CENTER_Y + (record.side == :above ? -BONE_DY : BONE_DY)
          bone = FishboneBone.new(record: record, attach_x: attach_x, attach_y: CENTER_Y, far_x: far_x, far_y: far_y, slot: slot).freeze
          bones << bone
          label_width = Text.grid(Text.width(record.label, CATEGORY_TEXT_SIZE) + 24)
          if label_width > CATEGORY_MAX_WIDTH
            raise LayoutError, "Fishbone category #{record.label.inspect} is too wide; shorten it, split the diagram, or widen the layout"
          end
          label_width = [label_width, CATEGORY_MIN_WIDTH].max
          top = record.side == :above ? far_y - CATEGORY_HEIGHT : far_y
          rect = [far_x - label_width / 2, top, far_x + label_width / 2, top + CATEGORY_HEIGHT].freeze
          boxes << FishboneBox.new(record: record, rect: rect, lines: [record.label].freeze).freeze
          text_bounds << [rect[0] + 12, rect[1] + 8, rect[2] - 12, rect[3] - 8].freeze

          FACTOR_FRACTIONS.fetch(record.factors.size).zip(record.factors).each_with_index do |(fraction, factor), index|
            start_x = attach_x - BONE_DX * fraction
            start_y = CENTER_Y + (far_y - CENTER_Y) * fraction
            end_x = start_x - FACTOR_TICK
            label_y = start_y + (record.side == :above ? -7 : 15)
            label_width = Text.width(factor, FACTOR_TEXT_SIZE, font: :mono)
            if label_width > 280
              raise LayoutError, "Fishbone factor #{factor.inspect} is too wide for its safe tick corridor; shorten it, split the diagram, or widen the layout"
            end
            label_rect = [end_x - 4 - label_width, label_y - FACTOR_TEXT_SIZE, end_x - 4, label_y + 3].freeze
            ticks << FishboneTick.new(category_id: record.id, factor: factor, start_x: start_x, start_y: start_y,
                                      end_x: end_x, end_y: start_y, label_x: end_x - 4, label_y: label_y,
                                      label_rect: label_rect).freeze
            text_bounds << label_rect
          end
        end
        validate_bounds!(width, effect_rect, boxes, text_bounds)
        validate_collisions!(boxes, ticks)
        FishboneScene.new(width: width, height: HEIGHT, head_x: head_x, center_y: CENTER_Y,
                          spine_start_x: [120.0, bones.map(&:far_x).min - 48.0].max, spine_end_x: head_x, effect_box: effect_box,
                          effect_text_bounds: effect_text_bounds,
                          category_boxes: boxes.freeze, bones: bones.freeze, ticks: ticks.freeze,
                          text_bounds: text_bounds.freeze).freeze
      end

      def self.overlap?(a, b, gap = 0)
        a[0] - gap < b[2] && a[2] + gap > b[0] && a[1] - gap < b[3] && a[3] + gap > b[1]
      end

      private

      def line_bounds(lines, center_x, center_y, size, budget, centered:)
        advance = size + 5
        top = center_y - (lines.size - 1) * advance / 2.0 - size
        lines.map.with_index do |line, index|
          width = [Text.width(line, size), budget].min
          x = centered ? center_x - width / 2 : center_x
          [x, top + index * advance, x + width, top + index * advance + size + 3].freeze
        end
      end

      def validate_bounds!(width, effect_rect, boxes, text_bounds)
        all = [effect_rect] + boxes.map(&:rect) + text_bounds
        return if all.all? { |rect| rect[0] >= 40 && rect[1] >= 24 && rect[2] <= width - 40 && rect[3] <= HEIGHT - 24 }
        raise LayoutError, 'Fishbone content exceeds the measured viewBox; shorten labels, split categories, or widen the diagram'
      end

      def validate_collisions!(boxes, ticks)
        rects = boxes.map(&:rect) + ticks.map(&:label_rect)
        rects.combination(2) do |left, right|
          if self.class.overlap?(left, right, 3)
            raise LayoutError, 'Fishbone labels collide; shorten factors, split categories, or widen the diagram'
          end
        end
      end
    end
  end
end
