# frozen_string_literal: true
module SlimGraphR
  module Layout
    ERScene = Struct.new(:width, :height, :boxes, :routes, keyword_init: true)
    ERBox = Struct.new(:entity, :x, :y, :width, :height, :field_rows, keyword_init: true)
    ERRoute = Struct.new(:relationship, :points, :from_port, :to_port, :label_box, keyword_init: true)

    class ER
      LEFT = 48
      TOP = 132
      COLUMN_GAP = 112
      ROW_GAP = 132
      RIGHT = 48
      BOTTOM = 36
      MIN_WIDTH = 168
      MAX_WIDTH = 224
      HEADER_HEIGHT = 28
      FIELD_INSET = 12

      def initialize(diagram) = @d = diagram

      def call
        columns = @d.entities.size <= 4 ? 2 : 3
        boxes = measure_boxes(columns)
        route_specs = @d.relationships.map { |item| route_spec(item, boxes, columns) }
        assign_ports!(route_specs)
        routes = route_specs.map.with_index { |spec, index| build_route(spec, boxes, index, columns) }
        validate_route_separation!(routes)
        max_x = boxes.map { |box| box.x + box.width }.max
        max_y = boxes.map { |box| box.y + box.height }.max
        ERScene.new(width: Text.grid(max_x + RIGHT), height: Text.grid(max_y + BOTTOM), boxes: boxes, routes: routes)
      end

      private

      def measure_boxes(columns)
        measured = @d.entities.map do |entity|
          required = [Text.width(entity.label, 12) + Text.width(er_kind_label(entity.kind), 8, font: :mono) + 42, MIN_WIDTH].max
          entity.fields.each do |field|
            glyph = field.key ? 18 : 0
            required = [required, Text.width(field_text(field), 10, font: :mono) + glyph + FIELD_INSET * 2].max
          end
          raise LayoutError, fit_error('entity or field text', entity.label) if required > MAX_WIDTH
          width = Text.grid(required)
          rows = entity.fields.map do |field|
            glyph = field.key ? 18 : 0
            text = field_text(field)
            lines = Text.wrap(text, width - FIELD_INSET * 2 - glyph, 10, font: :mono)
            raise LayoutError, fit_error('field text', text) if lines.size > 2
            { field: field, lines: lines, height: lines.size * 20 }
          end
          [entity, width, rows, HEADER_HEIGHT + rows.sum { |row| row[:height] } + 12]
        end
        row_tops = []
        measured.each_slice(columns).with_index do |row, index|
          row_tops[index] = index.zero? ? TOP : row_tops[index - 1] + measured.each_slice(columns).to_a[index - 1].map(&:last).max + ROW_GAP
        end
        measured.each_with_index.map do |(entity, width, rows, height), index|
          col = index % columns
          row = index / columns
          x = LEFT + col * (MAX_WIDTH + COLUMN_GAP)
          ERBox.new(entity: entity, x: x, y: row_tops[row], width: width, height: height, field_rows: rows)
        end
      end

      def route_spec(item, boxes, columns)
        from = boxes.find { |box| box.entity.id == item.from }
        to = boxes.find { |box| box.entity.id == item.to }
        from_index = boxes.index(from)
        to_index = boxes.index(to)
        from_col, to_col = from_index % columns, to_index % columns
        from_row, to_row = from_index / columns, to_index / columns
        if from_row == to_row && (from_col - to_col).abs > 1
          from_side = to_side = :top
        elsif from_col == to_col
          from_side = to.y > from.y ? :bottom : :top
          to_side = from.y > to.y ? :bottom : :top
        else
          from_side = to.x > from.x ? :right : :left
          to_side = from.x > to.x ? :right : :left
        end
        { relationship: item, from_box: from, to_box: to, from_side: from_side, to_side: to_side }
      end

      def assign_ports!(specs)
        uses = Hash.new { |hash, key| hash[key] = [] }
        specs.each do |spec|
          uses[[spec[:from_box].entity.id, spec[:from_side]]] << [spec, :from]
          uses[[spec[:to_box].entity.id, spec[:to_side]]] << [spec, :to]
        end
        uses.each_value do |entries|
          offsets = centered_offsets(entries.size)
          entries.each_with_index { |(spec, endpoint), index| spec["#{endpoint}_offset".to_sym] = offsets[index] }
        end
      end

      def centered_offsets(count)
        start = -(count - 1) * 6.0
        Array.new(count) { |index| start + index * 12.0 }
      end

      def build_route(spec, boxes, index, columns)
        from = port(spec[:from_box], spec[:from_side], spec[:from_offset])
        to = port(spec[:to_box], spec[:to_side], spec[:to_offset])
        if %i[left right].include?(spec[:from_side]) && %i[left right].include?(spec[:to_side])
          overlap_top = [spec[:from_box].y, spec[:to_box].y].max
          overlap_bottom = [spec[:from_box].y + spec[:from_box].height, spec[:to_box].y + spec[:to_box].height].min
          if overlap_bottom - overlap_top >= 32
            common_y = (overlap_top + overlap_bottom) / 2.0 + spec[:from_offset]
            from = [from[0], common_y]
            to = [to[0], common_y]
          end
        end
        points = if spec[:from_side] == :top && spec[:to_side] == :top
          lane_y = [spec[:from_box].y, spec[:to_box].y].min - 22 - index * 12
          [from, [from[0], lane_y], [to[0], lane_y], to]
        elsif %i[top bottom].include?(spec[:from_side]) && %i[top bottom].include?(spec[:to_side])
          [from, to]
        elsif from[1] == to[1]
          [from, to]
        else
          left_edge, right_edge = [spec[:from_box], spec[:to_box]].sort_by(&:x)
          corridor = (left_edge.x + left_edge.width + right_edge.x) / 2.0
          [from, [corridor, from[1]], [corridor, to[1]], to]
        end
        points = points.each_with_object([]) { |point, ary| ary << point unless ary.last == point }
        reject_obstructed!(points, boxes, spec)
        label_box = relationship_label(spec[:relationship], points)
        ERRoute.new(relationship: spec[:relationship], points: points,
                    from_port: { entity: spec[:from_box].entity.id, side: spec[:from_side], point: from },
                    to_port: { entity: spec[:to_box].entity.id, side: spec[:to_side], point: to },
                    label_box: label_box)
      end

      def port(box, side, offset)
        available = %i[left right].include?(side) ? box.height : box.width
        if offset.abs > available / 2.0 - 16
          raise LayoutError, fit_error('relationship ports', box.entity.label)
        end
        case side
        when :left then [box.x, box.y + box.height / 2.0 + offset]
        when :right then [box.x + box.width, box.y + box.height / 2.0 + offset]
        when :top then [box.x + box.width / 2.0 + offset, box.y]
        when :bottom then [box.x + box.width / 2.0 + offset, box.y + box.height]
        end
      end

      def reject_obstructed!(points, boxes, spec)
        unrelated = boxes - [spec[:from_box], spec[:to_box]]
        points.each_cons(2) do |a, b|
          unless a[0] == b[0] || a[1] == b[1]
            raise LayoutError, fit_error('relationship route', "#{spec[:relationship].from} to #{spec[:relationship].to}")
          end
          if unrelated.any? { |box| segment_hits_box?(a, b, box) }
            raise LayoutError, fit_error('relationship route', "#{spec[:relationship].from} to #{spec[:relationship].to}")
          end
        end
      end

      def segment_hits_box?(a, b, box)
        margin = 8
        if a[0] == b[0]
          a[0].between?(box.x - margin, box.x + box.width + margin) &&
            ranges_overlap?(*[a[1], b[1]].minmax, box.y - margin, box.y + box.height + margin)
        else
          a[1].between?(box.y - margin, box.y + box.height + margin) &&
            ranges_overlap?(*[a[0], b[0]].minmax, box.x - margin, box.x + box.width + margin)
        end
      end

      def ranges_overlap?(a1, a2, b1, b2) = a1 < b2 && b1 < a2

      def relationship_label(item, points)
        return nil unless item.label
        segments = points.each_cons(2).map { |a, b| [a, b, (a[0] - b[0]).abs + (a[1] - b[1]).abs] }
        a, b, length = segments.max_by(&:last)
        width = Text.width(item.label, 10) + 16
        raise LayoutError, fit_error('relationship label', item.label) if length < width + 24
        { x: (a[0] + b[0]) / 2.0, y: (a[1] + b[1]) / 2.0, width: width, height: 18, text: item.label }
      end

      def validate_route_separation!(routes)
        routes.combination(2) do |left, right|
          left.points.each_cons(2) do |a, b|
            right.points.each_cons(2) do |c, d|
              next unless segments_conflict?(a, b, c, d)
              raise LayoutError, fit_error('relationship routes', "#{left.relationship.from}:#{left.relationship.to} and #{right.relationship.from}:#{right.relationship.to}")
            end
          end
          [[left, right], [right, left]].each do |label_route, line_route|
            next unless label_route.label_box
            if line_route.points.each_cons(2).any? { |a, b| segment_hits_label?(a, b, label_route.label_box) }
              raise LayoutError, fit_error('relationship label clearance', label_route.relationship.label)
            end
          end
        end
      end

      def segments_conflict?(a, b, c, d)
        if a[1] == b[1] && c[1] == d[1]
          a[1] == c[1] && ranges_overlap?(*[a[0], b[0]].minmax, *[c[0], d[0]].minmax)
        elsif a[0] == b[0] && c[0] == d[0]
          a[0] == c[0] && ranges_overlap?(*[a[1], b[1]].minmax, *[c[1], d[1]].minmax)
        else
          horizontal, vertical = a[1] == b[1] ? [[a, b], [c, d]] : [[c, d], [a, b]]
          hx1, hx2 = [horizontal[0][0], horizontal[1][0]].minmax
          vy1, vy2 = [vertical[0][1], vertical[1][1]].minmax
          vertical[0][0].between?(hx1 + 8, hx2 - 8) && horizontal[0][1].between?(vy1 + 8, vy2 - 8)
        end
      end

      def segment_hits_label?(a, b, label)
        left = label[:x] - label[:width] / 2.0 - 8
        right = label[:x] + label[:width] / 2.0 + 8
        top = label[:y] - label[:height] / 2.0 - 8
        bottom = label[:y] + label[:height] / 2.0 + 8
        if a[0] == b[0]
          a[0].between?(left, right) && ranges_overlap?(*[a[1], b[1]].minmax, top, bottom)
        else
          a[1].between?(top, bottom) && ranges_overlap?(*[a[0], b[0]].minmax, left, right)
        end
      end

      def fit_error(kind, value)
        "ER #{kind} #{value.inspect} cannot be placed faithfully; shorten it or split the diagram"
      end

      def field_text(field)
        [field.label, field.type, field.qualifier && "· #{field.qualifier}"].compact.join(' ')
      end

      def er_kind_label(kind)
        kind.to_s.tr('_', ' ').upcase
      end
    end
  end
end
