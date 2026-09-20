# frozen_string_literal: true
module SlimGraphR
  module Layout
    VennCircle = Struct.new(:set, :cx, :cy, :r, keyword_init: true)
    VennLabel = Struct.new(:record, :text, :subtitle, :x, :y, :subtitle_y, :rect, :kind, keyword_init: true)
    VennScene = Struct.new(:width, :height, :circles, :set_labels, :region_labels, :focal, :caption, keyword_init: true)

    class Venn
      SET_TEXT_SIZE = 16
      SUBTITLE_TEXT_SIZE = 12
      REGION_TEXT_SIZE = 12
      LABEL_HEIGHT = 20.0
      STROKE_CLEARANCE = 8.0

      def initialize(diagram) = @d = diagram

      def call
        circles, set_positions, region_positions, width, height = template
        set_labels = @d.venn_sets.map.with_index do |item, index|
          label(item, set_positions.fetch(index), :set)
        end
        region_labels = @d.intersections.map do |item|
          key = item.sets.sort
          entry = label(item, region_positions.fetch(key), :region)
          validate_region!(entry, circles, item)
          entry
        end
        all = set_labels + region_labels
        all.combination(2) do |left, right|
          if self.class.overlap?(left.rect, right.rect)
            raise LayoutError, "Venn labels #{left.text.inspect} and #{right.text.inspect} overlap in the fixed template; shorten an overlap label or split the diagram"
          end
        end
        set_labels.each do |entry|
          circles.each do |circle|
            if self.class.rect_crosses_circle?(entry.rect, circle)
              raise LayoutError, "Venn set label #{entry.text.inspect} crosses a circle stroke; shorten the set label or split the diagram"
            end
          end
        end
        VennScene.new(width: width, height: height, circles: circles.freeze, set_labels: set_labels.freeze,
                      region_labels: region_labels.freeze, focal: @d.intersections.find(&:focal),
                      caption: 'Equal circles show named topology only; area and population are not quantitative.')
      end

      def self.overlap?(a, b)
        a[0] < b[2] && a[2] > b[0] && a[1] < b[3] && a[3] > b[1]
      end

      def self.rect_crosses_circle?(rect, circle)
        nearest_x = [[circle.cx, rect[0]].max, rect[2]].min
        nearest_y = [[circle.cy, rect[1]].max, rect[3]].min
        minimum = Math.hypot(nearest_x - circle.cx, nearest_y - circle.cy)
        maximum = [[rect[0], rect[1]], [rect[2], rect[1]], [rect[0], rect[3]], [rect[2], rect[3]]]
          .map { |x, y| Math.hypot(x - circle.cx, y - circle.cy) }.max
        minimum <= circle.r + STROKE_CLEARANCE && maximum >= circle.r - STROKE_CLEARANCE
      end

      private

      def template
        if @d.venn_sets.size == 2
          circles = [[360, 300, 224], [632, 300, 224]].map.with_index do |(cx, cy, r), i|
            VennCircle.new(set: @d.venn_sets.fetch(i), cx: cx, cy: cy, r: r)
          end
          positions = @d.venn_sets.any?(&:subtitle) ? [[360.0, 36.0], [632.0, 36.0]] : [[360.0, 52.0], [632.0, 52.0]]
          regions = { @d.venn_sets.map(&:id).sort => [496.0, 305.0] }
          [circles, positions, regions, 992, 584]
        else
          circles = [[380, 260, 192], [612, 260, 192], [496, 460, 192]].map.with_index do |(cx, cy, r), i|
            VennCircle.new(set: @d.venn_sets.fetch(i), cx: cx, cy: cy, r: r)
          end
          a, b, c = @d.venn_sets.map(&:id)
          positions = @d.venn_sets.any?(&:subtitle) ? [[300.0, 32.0], [692.0, 32.0], [496.0, 692.0]] : [[300.0, 48.0], [692.0, 48.0], [496.0, 692.0]]
          regions = {
            [a, b].sort => [496.0, 226.0], [a, c].sort => [398.0, 402.0],
            [b, c].sort => [594.0, 402.0], [a, b, c].sort => [496.0, 326.0]
          }
          [circles, positions, regions, 992, @d.venn_sets.any?(&:subtitle) ? 744 : 724]
        end
      end

      def label(record, position, kind)
        text = record.label
        subtitle = kind == :set ? record.subtitle : nil
        size = kind == :set ? SET_TEXT_SIZE : REGION_TEXT_SIZE
        width = [Text.width(text, size) + 8.0, subtitle ? Text.width(subtitle, SUBTITLE_TEXT_SIZE, font: :mono) + 8.0 : 0].max
        limit = kind == :set ? 220.0 : (@d.venn_sets.size == 2 ? 168.0 : 144.0)
        if width > limit
          noun = kind == :set ? 'set label' : 'overlap label'
          raise LayoutError, "Venn #{noun} #{text.inspect} cannot fit its clear fixed region; shorten the #{noun} or split the diagram"
        end
        x, y = position
        subtitle_y = subtitle ? y + 16 : nil
        bottom = subtitle ? subtitle_y + SUBTITLE_TEXT_SIZE / 2.0 : y - size + LABEL_HEIGHT
        VennLabel.new(record: record, text: text, subtitle: subtitle, x: x, y: y, subtitle_y: subtitle_y,
                      rect: [x - width / 2.0, y - size, x + width / 2.0, bottom].freeze,
                      kind: kind)
      end

      def validate_region!(entry, circles, intersection)
        corners = [[entry.rect[0], entry.rect[1]], [entry.rect[2], entry.rect[1]],
                   [entry.rect[0], entry.rect[3]], [entry.rect[2], entry.rect[3]]]
        members = intersection.sets
        circles.each do |circle|
          distances = corners.map { |x, y| Math.hypot(x - circle.cx, y - circle.cy) }
          valid = if members.include?(circle.set.id)
            distances.max <= circle.r - STROKE_CLEARANCE
          else
            distances.min >= circle.r + STROKE_CLEARANCE
          end
          next if valid
          raise LayoutError, "Venn overlap label #{entry.text.inspect} cannot fit its named fixed region while clearing every circle stroke; shorten the overlap label or split the diagram"
        end
      end
    end
  end
end
