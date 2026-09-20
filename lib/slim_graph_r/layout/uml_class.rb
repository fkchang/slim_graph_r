# frozen_string_literal: true
module SlimGraphR
  module Layout
    UMLClassScene = Struct.new(:width, :height, :boxes, :routes, :legend, keyword_init: true)
    UMLClassBox = Struct.new(:class_record, :x, :y, :width, :height, :name_height, :name_lines,
                             :attribute_rect, :attribute_rows, :operation_rect, :operation_rows, keyword_init: true)
    UMLClassRoute = Struct.new(:relation, :points, :from_port, :to_port, :from_label, :to_label, :label, keyword_init: true)

    class UMLClass
      PRIMARY_TEXT_SIZE = 12
      MEMBER_TEXT_SIZE = 9
      METADATA_TEXT_SIZE = 8
      LEFT = 48
      TOP = 132
      MIN_WIDTH = 184
      MAX_WIDTH = 280
      COLUMN_GAP = 104
      MEMBER_ROW_HEIGHT = 18
      LEGEND_HEIGHT = 112

      def initialize(diagram) = @d = diagram

      def call
        boxes = measure_boxes
        routes = build_routes(boxes)
        min_y = routes.flat_map(&:points).map(&:last).min
        shift = min_y < 28 ? 28 - min_y : 0
        if shift.positive?
          boxes.each { |box| box.y += shift; shift_box_rects!(box, shift) }
          routes.each { |route| shift_route!(route, shift) }
        end
        validate_routes!(routes, boxes)
        right = boxes.map { |box| box.x + box.width }.max
        bottom = boxes.map { |box| box.y + box.height }.max
        width = Text.grid([right + LEFT, 720].max)
        legend = { x: LEFT, y: bottom + 52, width: width - LEFT * 2, height: LEGEND_HEIGHT }
        UMLClassScene.new(width: width, height: Text.grid(legend[:y] + LEGEND_HEIGHT + 36), boxes: boxes,
                          routes: routes, legend: legend)
      end

      private

      def measure_boxes
        measured = @d.classes.map do |item|
          name_width = Text.width(item.label, PRIMARY_TEXT_SIZE) + 36
          stereotype_width = item.kind == :interface ? Text.width('«interface»', METADATA_TEXT_SIZE, font: :mono) + 36 : 0
          member_width = (item.attributes + item.operations).map { |value| Text.width(value, MEMBER_TEXT_SIZE, font: :mono) + 24 }.max || 0
          width = [[MIN_WIDTH, name_width, stereotype_width, member_width].max, MAX_WIDTH].min
          width = Text.grid(width)
          name_lines = Text.wrap(item.label, width - 24, PRIMARY_TEXT_SIZE)
          attribute_rows = member_rows(item.attributes, width)
          operation_rows = member_rows(item.operations, width)
          name_height = (item.kind == :interface ? 32 : 18) + name_lines.size * MEMBER_ROW_HEIGHT
          attr_height = attribute_rows.empty? ? 0 : attribute_rows.sum { |row| row[:height] } + 12
          op_height = operation_rows.empty? ? 0 : operation_rows.sum { |row| row[:height] } + 12
          if name_height + attr_height + op_height > 280
            raise LayoutError, fit_error('wrapped class/member text', item.label)
          end
          [item, width, name_height, name_lines, attribute_rows, attr_height, operation_rows, op_height]
        end
        x = LEFT
        measured.map do |item, width, name_height, name_lines, attribute_rows, attr_height, operation_rows, op_height|
          y = TOP
          attr_rect = attr_height.positive? ? [x, y + name_height, x + width, y + name_height + attr_height] : nil
          op_top = y + name_height + attr_height
          op_rect = op_height.positive? ? [x, op_top, x + width, op_top + op_height] : nil
          box = UMLClassBox.new(class_record: item, x: x, y: y, width: width,
                                height: name_height + attr_height + op_height, name_height: name_height,
                                name_lines: name_lines, attribute_rect: attr_rect, attribute_rows: attribute_rows,
                                operation_rect: op_rect, operation_rows: operation_rows)
          x += width + COLUMN_GAP
          box
        end
      end

      def member_rows(values, width)
        values.map do |value|
          lines = Text.wrap(value, width - 24, MEMBER_TEXT_SIZE, font: :mono)
          { value: value, lines: lines, height: lines.size * MEMBER_ROW_HEIGHT }
        end
      end

      def build_routes(boxes)
        usage = Hash.new { |hash, key| hash[key] = [] }
        specs = @d.relations.map.with_index do |relation, index|
          from_box = boxes.find { |box| box.class_record.id == relation.from }
          to_box = boxes.find { |box| box.class_record.id == relation.to }
          from_side = from_box.x < to_box.x ? :right : :left
          to_side = from_side == :right ? :left : :right
          spec = { relation: relation, index: index, from_box: from_box, to_box: to_box,
                   from_side: from_side, to_side: to_side }
          usage[[from_box.class_record.id, from_side]] << [spec, :from]
          usage[[to_box.class_record.id, to_side]] << [spec, :to]
          spec
        end
        usage.each_value do |entries|
          entries.sort_by! do |spec, _endpoint|
            -((boxes.index(spec[:from_box]) - boxes.index(spec[:to_box])).abs)
          end
          count = entries.size
          raise LayoutError, fit_error('relation ports', entries.first.first[:relation].from) if count > 5
          offsets = Array.new(count) { |i| (i - (count - 1) / 2.0) * 16 }
          entries.each_with_index { |(spec, endpoint), i| spec["#{endpoint}_offset".to_sym] = offsets[i] }
        end
        specs.map do |spec|
          from = endpoint(spec[:from_box], spec[:from_side], spec[:from_offset] || 0)
          to = endpoint(spec[:to_box], spec[:to_side], spec[:to_offset] || 0)
          adjacent = (boxes.index(spec[:from_box]) - boxes.index(spec[:to_box])).abs == 1
          points = if adjacent
            mid = (from[0] + to[0]) / 2.0
            [from, [mid, from[1]], [mid, to[1]], to]
          else
            lane_y = boxes.map(&:y).min - 28 - spec[:index] * 16
            distance = 20 + spec[:index] * 8
            from_stub = from[0] + (spec[:from_side] == :right ? distance : -distance)
            to_stub = to[0] + (spec[:to_side] == :right ? distance : -distance)
            [from, [from_stub, from[1]], [from_stub, lane_y], [to_stub, lane_y], [to_stub, to[1]], to]
          end
          points = points.each_with_object([]) { |point, out| out << point unless out.last == point }
          relation = spec[:relation]
          UMLClassRoute.new(relation: relation, points: points,
                            from_port: port(spec[:from_box], spec[:from_side], from),
                            to_port: port(spec[:to_box], spec[:to_side], to),
                            from_label: multiplicity_label(relation.from_multiplicity, from, spec[:from_side], :from),
                            to_label: multiplicity_label(relation.to_multiplicity, to, spec[:to_side], :to),
                            label: relation_label(relation.label, points))
        end
      end

      def endpoint(box, side, offset)
        y = box.y + box.height / 2.0 + offset
        unless y.between?(box.y + 10, box.y + box.height - 10)
          raise LayoutError, fit_error('relation port', box.class_record.label)
        end
        [side == :left ? box.x : box.x + box.width, y]
      end

      def port(box, side, point) = { class_id: box.class_record.id, side: side, point: point }

      def multiplicity_label(value, point, side, endpoint)
        return unless value
        width = Text.width(value, METADATA_TEXT_SIZE, font: :mono) + 10
        center_x = point[0] + (side == :left ? -12 - width / 2.0 : 12 + width / 2.0)
        { text: value, endpoint: endpoint, x: center_x, y: point[1], width: width, height: 14 }
      end

      def relation_label(value, points)
        return unless value
        width = Text.grid(Text.width(value, METADATA_TEXT_SIZE, font: :mono) + 12)
        segments = points.each_cons(2).select { |a, b| a[1] == b[1] && (a[0] - b[0]).abs >= width + 16 }
        raise LayoutError, fit_error('relation label', value) if segments.empty?
        a, b = segments.max_by { |left, right| (left[0] - right[0]).abs }
        { text: value, endpoint: :relation, x: (a[0] + b[0]) / 2.0, y: a[1] - 12, width: width, height: 14 }
      end

      def shift_box_rects!(box, amount)
        [box.attribute_rect, box.operation_rect].compact.each { |rect| rect[1] += amount; rect[3] += amount }
      end

      def shift_route!(route, amount)
        route.points.each { |point| point[1] += amount }
        [route.from_label, route.to_label, route.label].compact.each { |label| label[:y] += amount }
      end

      def validate_routes!(routes, boxes)
        routes.each do |route|
          route.points.each_cons(2) do |a, b|
            raise LayoutError, fit_error('route', route.relation.kind) unless a[0] == b[0] || a[1] == b[1]
            unrelated = boxes.reject { |box| [route.relation.from, route.relation.to].include?(box.class_record.id) }
            if unrelated.any? { |box| segment_hits_rect?(a, b, [box.x - 4, box.y - 4, box.x + box.width + 4, box.y + box.height + 4]) }
              raise LayoutError, fit_error('route', route.relation.kind)
            end
          end
        end
        labels = routes.flat_map { |route| [route.from_label, route.to_label, route.label].compact.map { |label| [route, label] } }
        labels.each_with_index do |(route, label), index|
          rect = label_rect(label)
          if boxes.any? { |box| rects_overlap?(rect, [box.x - 2, box.y - 2, box.x + box.width + 2, box.y + box.height + 2]) }
            raise LayoutError, fit_error('multiplicity label', route.relation.kind)
          end
          labels.drop(index + 1).each do |_other_route, other_label|
            raise LayoutError, fit_error('multiplicity labels', route.relation.kind) if rects_overlap?(rect, label_rect(other_label))
          end
          (routes - [route]).each do |other|
            if other.points.each_cons(2).any? { |a, b| segment_hits_rect?(a, b, rect) }
              raise LayoutError, fit_error('route/multiplicity clearance', route.relation.kind)
            end
          end
        end
        routes.each_with_index do |route, index|
          route.points.each_cons(2) do |a, b|
            routes.drop(index + 1).each do |other|
              other.points.each_cons(2) do |c, d|
                if segments_cross_or_overlap?(a, b, c, d)
                  raise LayoutError, fit_error('unmarked route crossing', "#{route.relation.kind}/#{other.relation.kind}")
                end
              end
            end
          end
        end
      end

      def label_rect(label)
        [label[:x] - label[:width] / 2.0, label[:y] - label[:height] / 2.0,
         label[:x] + label[:width] / 2.0, label[:y] + label[:height] / 2.0]
      end

      def rects_overlap?(a, b)
        a[0] < b[2] && a[2] > b[0] && a[1] < b[3] && a[3] > b[1]
      end

      def segment_hits_rect?(a, b, rect)
        if a[0] == b[0]
          a[0] > rect[0] && a[0] < rect[2] && [a[1], b[1]].min < rect[3] && [a[1], b[1]].max > rect[1]
        else
          a[1] > rect[1] && a[1] < rect[3] && [a[0], b[0]].min < rect[2] && [a[0], b[0]].max > rect[0]
        end
      end

      def segments_cross_or_overlap?(a, b, c, d)
        a_vertical = a[0] == b[0]
        c_vertical = c[0] == d[0]
        if a_vertical == c_vertical
          fixed_equal = a_vertical ? a[0] == c[0] : a[1] == c[1]
          return false unless fixed_equal
          first = a_vertical ? [a[1], b[1]].minmax : [a[0], b[0]].minmax
          second = c_vertical ? [c[1], d[1]].minmax : [c[0], d[0]].minmax
          [first[0], second[0]].max < [first[1], second[1]].min
        else
          vertical_a, vertical_b, horizontal_a, horizontal_b = a_vertical ? [a, b, c, d] : [c, d, a, b]
          x = vertical_a[0]
          y = horizontal_a[1]
          x.between?(*[horizontal_a[0], horizontal_b[0]].minmax) && y.between?(*[vertical_a[1], vertical_b[1]].minmax)
        end
      end

      def fit_error(part, label)
        "UML class #{part} for #{label.inspect} cannot fit without obscuring cards, routes, markers, or labels; split the model by package or shorten the literal text"
      end
    end
  end
end
