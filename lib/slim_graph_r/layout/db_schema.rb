# frozen_string_literal: true
module SlimGraphR
  module Layout
    DatabaseSchemaScene = Struct.new(:width, :height, :boxes, :routes, :schema_groups, keyword_init: true)
    DatabaseTableBox = Struct.new(:table, :x, :y, :width, :height, :header_rect, :column_rows, :overflow_row, :index_rows, keyword_init: true)
    DatabaseForeignKeyRoute = Struct.new(:foreign_key, :points, :from_port, :to_port, :label_box, keyword_init: true)

    class DatabaseSchema
      PRIMARY_TEXT_SIZE = 12
      METADATA_TEXT_SIZE = 9
      LEFT = 128
      TOP = 180
      MIN_WIDTH = 240
      MAX_WIDTH = 304
      COLUMN_GAP = 152
      ROW_GAP = 144
      HEADER_HEIGHT = 32
      ROW_HEIGHT = 24

      def initialize(diagram) = @d = diagram

      def call
        boxes = measure_boxes
        specs = @d.foreign_keys.map.with_index { |fk, index| route_spec(fk, boxes, index) }
        assign_sides_and_ports!(specs)
        routes = specs.map.with_index { |spec, index| build_route(spec, boxes, index) }
        groups = schema_groups(boxes)
        validate_routes!(routes, boxes, groups)
        max_x = [boxes.map { |box| box.x + box.width }.max, routes.flat_map(&:points).map(&:first).max].max
        max_y = [boxes.map { |box| box.y + box.height }.max, routes.flat_map(&:points).map(&:last).max].max
        DatabaseSchemaScene.new(
          width: Text.grid([max_x + 64, 720].max), height: Text.grid(max_y + 48),
          boxes: boxes, routes: routes, schema_groups: groups
        )
      end

      private

      def measure_boxes
        columns = @d.tables.size <= 2 ? 2 : 3
        measured = @d.tables.map do |table|
          required = [MIN_WIDTH, Text.width(table.label, PRIMARY_TEXT_SIZE) + Text.width('TABLE', METADATA_TEXT_SIZE, font: :mono) + 52].max
          table.columns.each do |column|
            chips = column.constraints.sum { |value| Text.width(value.to_s.upcase, METADATA_TEXT_SIZE, font: :mono) + 13 }
            row = Text.width(column.label, PRIMARY_TEXT_SIZE) + chips + Text.width(column.sql_type, METADATA_TEXT_SIZE, font: :mono) + 48
            required = [required, row].max
          end
          table.indexes.each { |name| required = [required, Text.width(name, METADATA_TEXT_SIZE, font: :mono) + 24].max }
          if table.overflow
            required = [required, Text.width("+ #{table.overflow.count} more columns", PRIMARY_TEXT_SIZE, font: :mono) + 24].max
          end
          raise LayoutError, fit_error('table content', table.label) if required > MAX_WIDTH
          width = Text.grid(required)
          overflow_height = table.overflow ? ROW_HEIGHT : 0
          index_height = table.indexes.empty? ? 0 : 24 + table.indexes.size * 20
          height = HEADER_HEIGHT + table.columns.size * ROW_HEIGHT + overflow_height + index_height
          [table, width, height]
        end
        rows = measured.each_slice(columns).to_a
        row_tops = []
        rows.each_with_index do |row, index|
          row_tops[index] = index.zero? ? TOP : row_tops[index - 1] + rows[index - 1].map(&:last).max + ROW_GAP
        end
        measured.each_with_index.map do |(table, width, height), index|
          col = index % columns
          row = index / columns
          x = LEFT + col * (MAX_WIDTH + COLUMN_GAP)
          y = row_tops[row]
          column_rows = table.columns.map.with_index do |column, row_index|
            top = y + HEADER_HEIGHT + row_index * ROW_HEIGHT
            { column: column, rect: [x, top, x + width, top + ROW_HEIGHT], center_y: top + ROW_HEIGHT / 2.0 }
          end
          overflow_top = y + HEADER_HEIGHT + table.columns.size * ROW_HEIGHT
          overflow_height = table.overflow ? ROW_HEIGHT : 0
          overflow_row = table.overflow && { overflow: table.overflow, rect: [x, overflow_top, x + width, overflow_top + ROW_HEIGHT] }
          index_top = overflow_top + overflow_height + 24
          index_rows = table.indexes.map.with_index do |name, row_index|
            { name: name, x: x + 12, y: index_top + row_index * 20 + 13 }
          end
          DatabaseTableBox.new(
            table: table, x: x, y: y, width: width, height: height,
            header_rect: [x, y, x + width, y + HEADER_HEIGHT], column_rows: column_rows, overflow_row: overflow_row, index_rows: index_rows
          )
        end
      end

      def route_spec(fk, boxes, index)
        from_box = boxes.find { |box| box.table.id == fk.from_table }
        to_box = boxes.find { |box| box.table.id == fk.to_table }
        from_row = from_box.column_rows.find { |row| row[:column].id == fk.from_column }
        to_row = to_box.column_rows.find { |row| row[:column].id == fk.to_column }
        { foreign_key: fk, from_box: from_box, to_box: to_box, from_row: from_row, to_row: to_row, index: index }
      end

      def assign_sides_and_ports!(specs)
        specs.each do |spec|
          delta = (spec[:to_box].x + spec[:to_box].width / 2.0) - (spec[:from_box].x + spec[:from_box].width / 2.0)
          if delta.positive?
            spec[:from_side], spec[:to_side] = :right, :left
          elsif delta.negative?
            spec[:from_side], spec[:to_side] = :left, :right
          else
            spec[:from_side], spec[:to_side] = spec[:index].even? ? %i[right left] : %i[left right]
          end
        end
        balance_overloaded_endpoint_sides!(specs)
        specs.each do |spec|
          from_center = spec[:from_box].x + spec[:from_box].width / 2.0
          to_center = spec[:to_box].x + spec[:to_box].width / 2.0
          spec[:from_side] = spec[:to_side] if from_center == to_center
          boxes = specs.flat_map { |item| [item[:from_box], item[:to_box]] }.uniq
          blocker_above = boxes.any? do |box|
            box != spec[:from_box] && box != spec[:to_box] && box.x == spec[:from_box].x && box.y < spec[:from_box].y
          end
          if blocker_above
            spec[:from_side] = opposite_side(spec[:from_side])
            spec[:exterior_source] = true
          end
        end
        uses = Hash.new { |hash, key| hash[key] = [] }
        specs.each do |spec|
          uses[[spec[:from_box].table.id, spec[:from_row][:column].id]] << [spec, :from]
          uses[[spec[:to_box].table.id, spec[:to_row][:column].id]] << [spec, :to]
        end
        uses.each do |key, entries|
          by_side = entries.group_by { |spec, endpoint| spec["#{endpoint}_side".to_sym] }
          raise LayoutError, fit_error('row ports', key.join('.')) if by_side.values.any? { |values| values.size > 2 }
          if entries.size <= 2
            offsets = entries.size == 2 ? [-8.0, 8.0] : [0.0]
            entries.each_with_index { |(spec, endpoint), i| spec["#{endpoint}_offset".to_sym] = offsets[i] }
          else
            by_side.each_value do |side_entries|
              side_entries = side_entries.sort_by do |spec, endpoint|
                own = spec["#{endpoint}_box".to_sym]
                other = spec[endpoint == :from ? :to_box : :from_box]
                -((other.x + other.width / 2.0) - (own.x + own.width / 2.0)).abs
              end
              offsets = side_entries.size == 2 ? [-8.0, 8.0] : [0.0]
              side_entries.each_with_index { |(spec, endpoint), i| spec["#{endpoint}_offset".to_sym] = offsets[i] }
            end
          end
          by_side.each_value do |side_entries|
            side_entries.select { |_spec, endpoint| endpoint == :to }.each_with_index do |(spec, _endpoint), index|
              spec[:to_corridor_distance] = 24 + index * 72
            end
          end
        end
      end

      def balance_overloaded_endpoint_sides!(specs)
        %i[from to].each do |endpoint|
          box_key = "#{endpoint}_box".to_sym
          row_key = "#{endpoint}_row".to_sym
          side_key = "#{endpoint}_side".to_sym
          specs.group_by { |spec| [spec[box_key].table.id, spec[row_key][:column].id] }.each_value do |items|
            next if items.size <= 1
            sorted = items.sort_by do |spec|
              other = spec[endpoint == :from ? :to_box : :from_box]
              own = spec[box_key]
              ((other.x + other.width / 2.0) - (own.x + own.width / 2.0)).abs
            end
            first_side = sorted.first[side_key]
            sorted.each_with_index do |spec, index|
              spec[side_key] = index.even? ? first_side : opposite_side(first_side)
            end
          end
        end
      end

      def opposite_side(side) = side == :left ? :right : :left

      def build_route(spec, boxes, index)
        from = endpoint(spec[:from_box], spec[:from_row], spec[:from_side], spec[:from_offset])
        to = endpoint(spec[:to_box], spec[:to_row], spec[:to_side], spec[:to_offset])
        points = route_points(from, to, spec, boxes, index)
        label = action_label(spec[:foreign_key], points, boxes)
        DatabaseForeignKeyRoute.new(
          foreign_key: spec[:foreign_key], points: points,
          from_port: port_record(spec, :from, from), to_port: port_record(spec, :to, to), label_box: label
        )
      end

      def endpoint(box, row, side, offset)
        y = row[:center_y] + offset
        unless y.between?(row[:rect][1] + 4, row[:rect][3] - 4)
          raise LayoutError, fit_error('row port', "#{box.table.id}.#{row[:column].id}")
        end
        [side == :left ? box.x : box.x + box.width, y]
      end

      def port_record(spec, endpoint, point)
        box = spec["#{endpoint}_box".to_sym]
        row = spec["#{endpoint}_row".to_sym]
        { table: box.table.id, column: row[:column].id, side: spec["#{endpoint}_side".to_sym], point: point }
      end

      def route_points(from, to, spec, boxes, index)
        same_column = spec[:from_box].x == spec[:to_box].x
        facing = (spec[:from_side] == :right && spec[:to_side] == :left && from[0] < to[0]) ||
                 (spec[:from_side] == :left && spec[:to_side] == :right && from[0] > to[0])
        if same_column && spec[:from_side] == spec[:to_side]
          lane = from[0] + (spec[:from_side] == :left ? -24 : 24)
          points = [from, [lane, from[1]], [lane, to[1]], to]
        elsif facing
          direction = to[0] > from[0] ? 1 : -1
          corridor = from[0] + direction * (20 + index * 4)
          points = [from, [corridor, from[1]], [corridor, to[1]], to]
          unrelated = boxes - [spec[:from_box], spec[:to_box]]
          if route_hits_boxes?(points, unrelated)
            lane_y = boxes.map(&:y).min - 64 - index * 20
            finish_corridor = to[0] - direction * (20 + index * 4)
            points = [from, [corridor, from[1]], [corridor, lane_y],
                      [finish_corridor, lane_y], [finish_corridor, to[1]], to]
          end
        else
          lane_y = [spec[:from_box].y, spec[:to_box].y].min - 64 - index * 20
          start_lane = if spec[:exterior_source]
            edge = spec[:from_side] == :left ? boxes.map(&:x).min : boxes.map { |box| box.x + box.width }.max
            edge + (spec[:from_side] == :left ? -24 - index * 12 : 24 + index * 12)
          else
            from[0] + (spec[:from_side] == :left ? -20 : 20) - index * 2
          end
          end_distance = spec[:to_corridor_distance] || 20 + index * 2
          end_lane = to[0] + (spec[:to_side] == :left ? -end_distance : end_distance)
          points = [from, [start_lane, from[1]], [start_lane, lane_y], [end_lane, lane_y], [end_lane, to[1]], to]
        end
        points.each_with_object([]) { |point, output| output << point unless output.last == point }
      end

      def action_label(fk, points, boxes)
        value = "ON DELETE #{fk.on_delete.to_s.tr('_', ' ').upcase}"
        width = Text.width(value, METADATA_TEXT_SIZE, font: :mono) + 16
        segments = points.each_cons(2).map { |a, b| [a, b, (a[0] - b[0]).abs + (a[1] - b[1]).abs] }
        candidates = segments.select do |a, b, length|
          length >= (a[1] == b[1] ? width + 20 : 36)
        end.sort_by { |item| item[0][1] == item[1][1] ? -item[2] : -item[2] + 10_000 }
        candidate = candidates.find do |a, b, _length|
          label = { x: (a[0] + b[0]) / 2.0, y: (a[1] + b[1]) / 2.0, width: width, height: 16, text: value }
          boxes.none? { |box| box_contains_label?(box, label) }
        end
        raise LayoutError, fit_error('foreign-key action label', value) unless candidate
        a, b = candidate
        { x: (a[0] + b[0]) / 2.0, y: (a[1] + b[1]) / 2.0, width: width, height: 16, text: value }
      end

      def schema_groups(boxes)
        runs = boxes.slice_when { |left, right| left.table.schema != right.table.schema }.to_a
        runs.select { |members| members.first.table.schema }.map do |members|
          schema = members.first.table.schema
          left = members.map(&:x).min - 16
          top = members.map(&:y).min - 28
          right = members.map { |box| box.x + box.width }.max + 16
          bottom = members.map { |box| box.y + box.height }.max + 16
          { schema: schema, rect: [left, top, right, bottom], members: members.map { |box| box.table.id } }
        end
      end

      def validate_routes!(routes, boxes, groups)
        routes.each do |route|
          route.points.each_cons(2) do |a, b|
            unless a[0] == b[0] || a[1] == b[1]
              raise LayoutError, fit_error('foreign-key path', "#{route.foreign_key.from_table} to #{route.foreign_key.to_table}")
            end
          end
          endpoints = [route.from_port[:table], route.to_port[:table]]
          unrelated = boxes.reject { |box| endpoints.include?(box.table.id) }
          if route_hits_boxes?(route.points, unrelated)
            raise LayoutError, fit_error('foreign-key card clearance', "#{route.foreign_key.from_table} to #{route.foreign_key.to_table}")
          end
          if boxes.any? { |box| box_contains_label?(box, route.label_box) }
            raise LayoutError, fit_error('foreign-key action-label clearance', route.label_box[:text])
          end
        end
        routes.combination(2) do |left, right|
          left.points.each_cons(2) do |a, b|
            right.points.each_cons(2) do |c, d|
              if segments_conflict?(a, b, c, d)
                raise LayoutError, fit_error('foreign-key route separation',
                                             "#{left.foreign_key.from_table} and #{right.foreign_key.from_table}")
              end
            end
          end
          [[left, right], [right, left]].each do |label_route, line_route|
            if line_route.points.each_cons(2).any? { |a, b| segment_hits_label?(a, b, label_route.label_box) }
              raise LayoutError, fit_error('foreign-key action-label route clearance', label_route.label_box[:text])
            end
          end
        end
        groups.each do |group|
          x, y, right, bottom = group[:rect]
          unless x >= 0 && y >= 0 && right > x && bottom > y
            raise LayoutError, fit_error('schema group', group[:schema])
          end
        end
      end

      def route_hits_boxes?(points, boxes)
        points.each_cons(2).any? do |a, b|
          boxes.any? { |box| segment_hits_box?(a, b, box) }
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

      def box_contains_label?(box, label)
        left = label[:x] - label[:width] / 2.0
        right = label[:x] + label[:width] / 2.0
        top = label[:y] - label[:height] / 2.0
        bottom = label[:y] + label[:height] / 2.0
        ranges_overlap?(left, right, box.x - 8, box.x + box.width + 8) &&
          ranges_overlap?(top, bottom, box.y - 8, box.y + box.height + 8)
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

      def ranges_overlap?(a1, a2, b1, b2) = a1 < b2 && b1 < a2

      def segments_conflict?(a, b, c, d)
        if a[1] == b[1] && c[1] == d[1]
          a[1] == c[1] && ranges_overlap?(*[a[0], b[0]].minmax, *[c[0], d[0]].minmax)
        elsif a[0] == b[0] && c[0] == d[0]
          a[0] == c[0] && ranges_overlap?(*[a[1], b[1]].minmax, *[c[1], d[1]].minmax)
        else
          horizontal, vertical = a[1] == b[1] ? [[a, b], [c, d]] : [[c, d], [a, b]]
          hx1, hx2 = [horizontal[0][0], horizontal[1][0]].minmax
          vy1, vy2 = [vertical[0][1], vertical[1][1]].minmax
          vertical[0][0].between?(hx1, hx2) && horizontal[0][1].between?(vy1, vy2)
        end
      end

      def fit_error(kind, value)
        "Database schema #{kind} #{value.inspect} cannot be laid out faithfully; shorten it or split the subsystem"
      end
    end
  end
end
