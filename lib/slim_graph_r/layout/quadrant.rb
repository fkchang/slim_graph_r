# frozen_string_literal: true
module SlimGraphR
  module Layout
    QuadrantScene = Struct.new(:width, :height, :plot, :center_x, :center_y, :points, :axis_labels, :regions, :caption, keyword_init: true)
    QuadrantPoint = Struct.new(:item, :cx, :cy, :label_x, :label_y, :label_anchor, :label_rect, keyword_init: true)

    class Quadrant
      WIDTH = 904
      PLOT_LEFT = 92.0
      PLOT_TOP = 68.0
      PLOT_WIDTH = 720.0
      PLOT_HEIGHT = 480.0
      POINT_TEXT_SIZE = 10
      AXIS_TEXT_SIZE = 8
      CAPTION_TEXT_SIZE = 10
      DOT_RADIUS = 4.0
      AXIS_CLEARANCE = 8.0
      BOUNDARY_CLEARANCE = 4.0
      LABEL_GAP = 10.0

      def initialize(diagram) = @d = diagram

      def call
        center_x = PLOT_LEFT + PLOT_WIDTH / 2.0
        center_y = PLOT_TOP + PLOT_HEIGHT / 2.0
        dots = @d.items.map do |item|
          [item, PLOT_LEFT + ((item.x + 1.0) / 2.0) * PLOT_WIDTH,
           PLOT_TOP + ((1.0 - item.y) / 2.0) * PLOT_HEIGHT]
        end
        regions = place_regions(center_x, center_y)
        placed = regions.map { |region| region[:rect] }
        points = dots.map do |item, cx, cy|
          placement = place_label(item, cx, cy, dots, placed, center_x, center_y)
          placed << placement[:rect]
          QuadrantPoint.new(item: item, cx: cx, cy: cy, label_x: placement[:x], label_y: placement[:y],
                            label_anchor: placement[:anchor], label_rect: placement[:rect].freeze)
        end
        axis_labels = measure_axis_labels(center_x, center_y)
        QuadrantScene.new(width: WIDTH, height: 628, plot: [PLOT_LEFT, PLOT_TOP, PLOT_WIDTH, PLOT_HEIGHT].freeze,
                          center_x: center_x, center_y: center_y, points: points.freeze,
                          axis_labels: axis_labels.freeze, regions: regions.freeze,
                          caption: 'Positions are qualitative author judgments, not calculated scores.')
      end

      private

      def place_regions(center_x, center_y)
        locations = {
          upper_left: [PLOT_LEFT + 18, PLOT_TOP + 22, 'start'], upper_right: [PLOT_LEFT + PLOT_WIDTH - 18, PLOT_TOP + 22, 'end'],
          lower_left: [PLOT_LEFT + 18, PLOT_TOP + PLOT_HEIGHT - 12, 'start'], lower_right: [PLOT_LEFT + PLOT_WIDTH - 18, PLOT_TOP + PLOT_HEIGHT - 12, 'end']
        }
        @d.quadrant_regions.map do |region|
          x, y, anchor = locations.fetch(region.position)
          width = Text.width(region.label, AXIS_TEXT_SIZE, font: :mono) + 2
          left = anchor == 'end' ? x - width : x
          rect = [left, y - AXIS_TEXT_SIZE, left + width, y + 4].freeze
          unless inside_plot?(rect)
            raise LayoutError, "Quadrant region label #{region.label.inspect} cannot fit in its named corner; shorten the label or split the quadrant"
          end
          { record: region, x: x, y: y, anchor: anchor, rect: rect }.freeze
        end
      end

      def place_label(item, cx, cy, dots, placed, center_x, center_y)
        width = Text.width(item.label, POINT_TEXT_SIZE) + 2
        height = 14.0
        horizontal = item.x.positive? ? %i[right left] : %i[left right]
        vertical = item.y.positive? ? %i[above level below] : %i[below level above]
        candidates = horizontal.product(vertical).map do |h, v|
          label_x = h == :right ? cx + DOT_RADIUS + LABEL_GAP : cx - DOT_RADIUS - LABEL_GAP
          anchor = h == :right ? 'start' : 'end'
          left = h == :right ? label_x : label_x - width
          label_y = case v when :above then cy - DOT_RADIUS - LABEL_GAP
                    when :below then cy + DOT_RADIUS + LABEL_GAP + POINT_TEXT_SIZE
                    else cy + POINT_TEXT_SIZE / 3.0
                    end
          top = label_y - POINT_TEXT_SIZE
          { x: label_x, y: label_y, anchor: anchor, rect: [left, top, left + width, top + height] }
        end
        placement = candidates.find do |candidate|
          rect = candidate[:rect]
          inside_plot?(rect) && inside_authored_quadrant?(rect, item, center_x, center_y) &&
            clears_axes?(rect, center_x, center_y) && clears_dots?(rect, dots) &&
            placed.none? { |other| overlap?(expand(rect, 3), expand(other, 3)) }
        end
        return placement if placement
        raise LayoutError, "Quadrant label #{item.label.inspect} cannot fit in its authored quadrant while clearing axes, dots, labels, and boundaries; shorten the label, spread the authored positions, or split the quadrant"
      end

      def inside_plot?(rect)
        rect[0] >= PLOT_LEFT + BOUNDARY_CLEARANCE && rect[2] <= PLOT_LEFT + PLOT_WIDTH - BOUNDARY_CLEARANCE &&
          rect[1] >= PLOT_TOP + BOUNDARY_CLEARANCE && rect[3] <= PLOT_TOP + PLOT_HEIGHT - BOUNDARY_CLEARANCE
      end

      def inside_authored_quadrant?(rect, item, center_x, center_y)
        horizontal = item.x.positive? ? rect[0] > center_x + AXIS_CLEARANCE : rect[2] < center_x - AXIS_CLEARANCE
        vertical = item.y.positive? ? rect[3] < center_y - AXIS_CLEARANCE : rect[1] > center_y + AXIS_CLEARANCE
        horizontal && vertical
      end

      def clears_axes?(rect, center_x, center_y)
        !overlap?(rect, [center_x - AXIS_CLEARANCE, PLOT_TOP, center_x + AXIS_CLEARANCE, PLOT_TOP + PLOT_HEIGHT]) &&
          !overlap?(rect, [PLOT_LEFT, center_y - AXIS_CLEARANCE, PLOT_LEFT + PLOT_WIDTH, center_y + AXIS_CLEARANCE])
      end

      def clears_dots?(rect, dots)
        dots.none? do |_item, x, y|
          overlap?(rect, [x - DOT_RADIUS - 4, y - DOT_RADIUS - 4, x + DOT_RADIUS + 4, y + DOT_RADIUS + 4])
        end
      end

      def measure_axis_labels(center_x, center_y)
        labels = [
          { side: :left, text: @d.horizontal_axis_record.low, x: PLOT_LEFT - 12, y: center_y + 3, anchor: 'end' },
          { side: :right, text: @d.horizontal_axis_record.high, x: PLOT_LEFT + PLOT_WIDTH + 12, y: center_y + 3, anchor: 'start' },
          { side: :top, text: @d.vertical_axis_record.high, x: center_x, y: PLOT_TOP - 16, anchor: 'middle' },
          { side: :bottom, text: @d.vertical_axis_record.low, x: center_x, y: PLOT_TOP + PLOT_HEIGHT + 24, anchor: 'middle' }
        ]
        labels.each do |label|
          width = Text.width(label[:text], AXIS_TEXT_SIZE, font: :mono)
          fits = case label[:side]
                 when :left then width <= PLOT_LEFT - 20
                 when :right then width <= WIDTH - (PLOT_LEFT + PLOT_WIDTH) - 20
                 else width <= PLOT_WIDTH / 2.0 - 24
                 end
          unless fits
            raise LayoutError, "Quadrant axis phrase #{label[:text].inspect} cannot fit beyond its arrow tip; shorten the literal axis phrase"
          end
        end
        labels
      end

      def expand(rect, amount) = [rect[0] - amount, rect[1] - amount, rect[2] + amount, rect[3] + amount]
      def overlap?(a, b) = a[0] < b[2] && a[2] > b[0] && a[1] < b[3] && a[3] > b[1]
    end
  end
end
