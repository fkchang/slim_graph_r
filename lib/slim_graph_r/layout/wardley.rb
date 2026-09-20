# frozen_string_literal: true
module SlimGraphR
  module Layout
    WardleyScene = Struct.new(:width, :height, :plot, :points, :dependencies, :movements, :bands, :caption, keyword_init: true)
    WardleyPoint = Struct.new(:component, :cx, :cy, :label_x, :label_y, :label_rect, :label_lane, keyword_init: true)
    WardleyLine = Struct.new(:record, :x1, :y1, :x2, :y2, :points, keyword_init: true)

    class Wardley
      PLOT_LEFT = 112.0
      PLOT_TOP = 56.0
      PLOT_WIDTH = 960.0
      PLOT_HEIGHT = 480.0
      BAND_WIDTH = PLOT_WIDTH / 4.0
      MAX_PLOT_HEIGHT = 960.0
      DOT_RADIUS = 6.0
      POINT_TEXT_SIZE = 12
      AXIS_TEXT_SIZE = 12
      CAPTION_TEXT_SIZE = 12
      LABEL_GAP = 12.0
      CLEARANCE = 6.0
      MOVEMENT_LENGTH = 76.0
      CAPTION = 'Band and visibility positions are qualitative author judgments, not calculated scores.'
      BAND_NAMES = ['GENESIS', 'CUSTOM-BUILT', 'PRODUCT', 'COMMODITY'].freeze

      def initialize(diagram) = @d = diagram

      def call
        points, dependencies, movements, plot_height = measured_label_layout
        bands = BAND_NAMES.each_with_index.map do |label, index|
          { label: label, cx: PLOT_LEFT + index * BAND_WIDTH + BAND_WIDTH / 2.0, separator_x: PLOT_LEFT + index * BAND_WIDTH }
        end
        WardleyScene.new(width: 1120, height: PLOT_TOP + plot_height + 128, plot: [PLOT_LEFT, PLOT_TOP, PLOT_WIDTH, plot_height].freeze,
                         points: points.freeze, dependencies: dependencies.freeze, movements: movements.freeze,
                         bands: bands.freeze, caption: CAPTION)
      end

      private

      # Authored dots retain their qualitative band and visibility fraction. The
      # plot expands vertically in measured four-pixel steps before any label or
      # collision rule is relaxed.
      def measured_label_layout
        last_failure = nil
        PLOT_HEIGHT.to_i.step(MAX_PLOT_HEIGHT.to_i, 4) do |plot_height|
          begin
            points = @d.wardley_components.map { |component| point_for(component, plot_height) }
            point_by_id = points.to_h { |point| [point.component.id, point] }
            dependencies = @d.wardley_dependencies.map do |record|
              from, to = point_by_id.fetch(record.from), point_by_id.fetch(record.to)
              WardleyLine.new(record: record, x1: from.cx, y1: from.cy, x2: to.cx, y2: to.cy,
                              points: [[from.cx, from.cy], [to.cx, to.cy]].freeze)
            end
            points = place_label_lanes(points, dependencies, plot_height)
            movements = points.filter_map do |point|
              next unless point.component.evolving_to
              WardleyLine.new(record: point.component, x1: point.cx + DOT_RADIUS + 2, y1: point.cy,
                              x2: point.cx + DOT_RADIUS + 2 + MOVEMENT_LENGTH, y2: point.cy,
                              points: [[point.cx + DOT_RADIUS + 2, point.cy], [point.cx + DOT_RADIUS + 2 + MOVEMENT_LENGTH, point.cy]].freeze)
            end
            validate_geometry!(points, dependencies, movements, PLOT_WIDTH, plot_height, BAND_WIDTH)
            return [points, dependencies, movements, plot_height]
          rescue LayoutError => error
            last_failure = error
          end
        end
        raise(last_failure || LayoutError.new('Wardley labels cannot fit the bounded qualitative-band layout; shorten labels, spread authored visibility positions, or split the map'))
      end

      def point_for(component, plot_height)
        cx = PLOT_LEFT + WardleyDSL::EVOLUTION.index(component.evolution) * BAND_WIDTH + BAND_WIDTH / 2.0
        cy = PLOT_TOP + (1.0 - component.visibility) * plot_height
        width = Text.width(component.label, POINT_TEXT_SIZE) + 2
        label_y = cy - DOT_RADIUS - LABEL_GAP
        rect = [cx - width / 2.0, label_y - POINT_TEXT_SIZE, cx + width / 2.0, label_y + 3]
        WardleyPoint.new(component: component, cx: cx, cy: cy, label_x: cx, label_y: label_y,
                         label_rect: rect.freeze, label_lane: :above)
      end

      def place_label_lanes(points, dependencies, plot_height)
        placed = []
        ordered = points.sort_by do |point|
          [[point.cy - PLOT_TOP, PLOT_TOP + plot_height - point.cy].min, points.index(point)]
        end
        ordered.each do |point|
          width = Text.width(point.component.label, POINT_TEXT_SIZE) + 2
          candidates = [
            [:above, point.cx, point.cy - DOT_RADIUS - LABEL_GAP,
             [point.cx - width / 2.0, point.cy - DOT_RADIUS - LABEL_GAP - POINT_TEXT_SIZE, point.cx + width / 2.0, point.cy - DOT_RADIUS - LABEL_GAP + 3]],
            [:below, point.cx, point.cy + DOT_RADIUS + LABEL_GAP + POINT_TEXT_SIZE,
             [point.cx - width / 2.0, point.cy + DOT_RADIUS + LABEL_GAP, point.cx + width / 2.0, point.cy + DOT_RADIUS + LABEL_GAP + POINT_TEXT_SIZE + 3]],
            [:left, point.cx - DOT_RADIUS - LABEL_GAP - width / 2.0, point.cy + 4,
             [point.cx - DOT_RADIUS - LABEL_GAP - width, point.cy - POINT_TEXT_SIZE + 4, point.cx - DOT_RADIUS - LABEL_GAP, point.cy + 7]],
            [:right, point.cx + DOT_RADIUS + LABEL_GAP + width / 2.0, point.cy + 4,
             [point.cx + DOT_RADIUS + LABEL_GAP, point.cy - POINT_TEXT_SIZE + 4, point.cx + DOT_RADIUS + LABEL_GAP + width, point.cy + 7]]
          ]
          selected = candidates.find do |_lane, _x, _y, rect|
            label_rect_clear?(point, rect, points, placed, dependencies, plot_height)
          end
          layout_failure(point.component.label, 'has no measured label lane at its authored position') unless selected
          lane, label_x, label_y, rect = selected
          placed << WardleyPoint.new(component: point.component, cx: point.cx, cy: point.cy,
                                     label_x: label_x, label_y: label_y, label_rect: rect.freeze, label_lane: lane)
        end
        by_id = placed.to_h { |point| [point.component.id, point] }
        points.map { |point| by_id.fetch(point.component.id) }
      end

      def label_rect_clear?(point, rect, points, placed, dependencies, plot_height)
        plot_right = PLOT_LEFT + PLOT_WIDTH
        plot_bottom = PLOT_TOP + plot_height
        band_index = WardleyDSL::EVOLUTION.index(point.component.evolution)
        band_left = PLOT_LEFT + band_index * BAND_WIDTH
        band_right = band_left + BAND_WIDTH
        return false unless rect[0] >= [PLOT_LEFT, band_left].max + CLEARANCE &&
                            rect[2] <= [plot_right, band_right].min - CLEARANCE &&
                            rect[1] >= PLOT_TOP + CLEARANCE && rect[3] <= plot_bottom - CLEARANCE
        return false if points.any? { |other| !other.equal?(point) && rect_circle_interfere?(rect, other.cx, other.cy, DOT_RADIUS + CLEARANCE) }
        return false if placed.any? { |other| rect_overlap?(expand(rect, CLEARANCE), expand(other.label_rect, CLEARANCE)) }
        dependencies.none? do |line|
          next false if [line.record.from, line.record.to].include?(point.component.id)
          segment_rect_interfere?(line, expand(rect, CLEARANCE))
        end
      end

      # Dependencies use rectilinear visibility lanes around authored dots and
      # measured labels. Perpendicular crossings remain semantic crossings and
      # are rendered with a bridge; parallel routes must reserve distinct lanes.
      def route_dependencies(points, point_by_id, plot_height)
        obstacles = points.flat_map do |point|
          dot = Box.new(node: point.component, x: point.cx - DOT_RADIUS, y: point.cy - DOT_RADIUS,
                        width: DOT_RADIUS * 2, height: DOT_RADIUS * 2)
          left, top, right, bottom = point.label_rect
          label = Box.new(node: point.component, x: left, y: top, width: right - left, height: bottom - top)
          [dot, label]
        end
        connections = @d.wardley_dependencies.map do |record|
          from, to = point_by_id.fetch(record.from), point_by_id.fetch(record.to)
          { record: record, from: from, to: to }
        end
        rects = obstacles.map { |box| box.rect(CLEARANCE) } + [[0, 0, PLOT_LEFT - CLEARANCE, PLOT_TOP + plot_height]]
        committed = []
        routed = {}
        connections.sort_by do |item|
          [-((item[:from].cx - item[:to].cx).abs + (item[:from].cy - item[:to].cy).abs),
           item[:record].from, item[:record].to]
        end.each do |item|
          choices = dependency_port_pairs(item[:from], item[:to], item[:record]).filter_map.with_index do |(start, finish), preference|
            route = wardley_lane_route(start, finish, rects, committed, plot_height)
            length = route.each_cons(2).sum { |a, b| (a[0] - b[0]).abs + (a[1] - b[1]).abs }
            [preference, length + (route.size - 2) * 24, route]
          rescue LayoutError
            nil
          end
          raise LayoutError, 'Could not route this connection. Split the graph into smaller diagrams.' if choices.empty?
          middle = choices.min_by { |preference, length, _route| [preference / 4, length, preference] }.last
          committed.concat(middle.each_cons(2).to_a)
          points_for_line = Geometry.compact([[item[:from].cx, item[:from].cy]] + middle + [[item[:to].cx, item[:to].cy]])
          routed[item[:record].object_id] = WardleyLine.new(
            record: item[:record], x1: item[:from].cx, y1: item[:from].cy,
            x2: item[:to].cx, y2: item[:to].cy, points: points_for_line.freeze
          )
        rescue LayoutError => error
          layout_failure(item[:from].component.label, "dependency to #{item[:to].component.label.inspect} cannot reserve a clear routing lane (#{error.message})")
        end
        @d.wardley_dependencies.map { |record| routed.fetch(record.object_id) }
      end

      def wardley_lane_route(start, finish, obstacles, committed, plot_height)
        right = PLOT_LEFT + PLOT_WIDTH
        bottom = PLOT_TOP + plot_height
        x_lanes = ([PLOT_LEFT + CLEARANCE, right - CLEARANCE, start[0], finish[0]] + PLOT_LEFT.step(right, 12).to_a +
          obstacles.flat_map { |rect| [rect[0] - CLEARANCE, rect[2] + CLEARANCE] }).uniq
          .select { |x| x.between?(PLOT_LEFT + CLEARANCE, right - CLEARANCE) }.sort
        y_lanes = ([PLOT_TOP + CLEARANCE, bottom - CLEARANCE, start[1], finish[1]] + PLOT_TOP.step(bottom, 12).to_a +
          obstacles.flat_map { |rect| [rect[1] - CLEARANCE, rect[3] + CLEARANCE] }).uniq
          .select { |y| y.between?(PLOT_TOP + CLEARANCE, bottom - CLEARANCE) }.sort
        candidates = []
        candidates << [start, finish] if start[0] == finish[0] || start[1] == finish[1]
        candidates.concat(x_lanes.map { |x| [start, [x, start[1]], [x, finish[1]], finish] })
        candidates.concat(y_lanes.map { |y| [start, [start[0], y], [finish[0], y], finish] })
        source_lanes = x_lanes.select do |x|
          obstacles.none? { |rect| Geometry.blocked?(start, [x, start[1]], rect) }
        end.sort_by { |x| (x - start[0]).abs }.first(30)
        target_lanes = x_lanes.select do |x|
          obstacles.none? { |rect| Geometry.blocked?([x, finish[1]], finish, rect) }
        end.sort_by { |x| (x - finish[0]).abs }.first(30)
        source_lanes.product(target_lanes, y_lanes).each do |source_x, target_x, y|
          candidates << [start, [source_x, start[1]], [source_x, y], [target_x, y], [target_x, finish[1]], finish]
        end
        valid = candidates.map { |points| Geometry.compact(points) }.uniq.select do |points|
          points.each_cons(2).all? do |a, b|
            obstacles.none? { |rect| Geometry.blocked?(a, b, rect) }
          end
        end
        route = valid.min_by do |points|
          length = points.each_cons(2).sum { |a, b| (a[0] - b[0]).abs + (a[1] - b[1]).abs }
          conflicts = points.each_cons(2).sum do |a, b|
            committed.count { |c, d| Geometry.parallel_conflict?(a, b, c, d, gap: CLEARANCE) }
          end
          [conflicts, length + (points.size - 2) * 24, points.flatten]
        end
        raise LayoutError, 'Could not route this connection. Split the graph into smaller diagrams.' unless route
        route
      end

      def dependency_port_pairs(from, to, record)
        distance = DOT_RADIUS + CLEARANCE
        preferred = []
        if from.component.evolution != to.component.evolution
          direction = to.cx < from.cx ? -1 : 1
          preferred << [direction.positive? ? :right : :left, direction.positive? ? :left : :right]
        end
        sides = %i[right left bottom top]
        from_incident = @d.wardley_dependencies.select { |item| [item.from, item.to].include?(from.component.id) }
        to_incident = @d.wardley_dependencies.select { |item| [item.from, item.to].include?(to.component.id) }
        preferred << [sides.fetch(from_incident.index(record) % sides.size), sides.fetch(to_incident.index(record) % sides.size)]
        pairs = (preferred + sides.product(sides)).uniq
        pairs.map { |from_side, to_side| [wardley_port(from, from_side, distance), wardley_port(to, to_side, distance)] }
      end

      def wardley_port(point, side, distance)
        case side
        when :right then [point.cx + distance, point.cy]
        when :left then [point.cx - distance, point.cy]
        when :bottom then [point.cx, point.cy + distance]
        when :top then [point.cx, point.cy - distance]
        end
      end

      def validate_geometry!(points, dependencies, movements, plot_width, plot_height, band_width)
        plot_right = PLOT_LEFT + plot_width
        plot_bottom = PLOT_TOP + plot_height
        points.each do |point|
          rect = point.label_rect
          unless rect[0] >= PLOT_LEFT + CLEARANCE && rect[2] <= plot_right - CLEARANCE &&
                 rect[1] >= PLOT_TOP + CLEARANCE && rect[3] <= plot_bottom - CLEARANCE
            layout_failure(point.component.label, 'label cannot clear the map axes and boundaries')
          end
          band_index = WardleyDSL::EVOLUTION.index(point.component.evolution)
          band_left = PLOT_LEFT + band_index * band_width
          band_right = band_left + band_width
          unless rect[0] >= band_left + CLEARANCE && rect[2] <= band_right - CLEARANCE
            layout_failure(point.component.label, 'label cannot remain inside its authored qualitative band')
          end
          points.each do |other|
            next if other.equal?(point)
            if rect_circle_interfere?(rect, other.cx, other.cy, DOT_RADIUS + CLEARANCE)
              layout_failure(point.component.label, "label interferes with component #{other.component.label.inspect}")
            end
          end
        end
        points.combination(2) do |a, b|
          if rect_overlap?(expand(a.label_rect, CLEARANCE), expand(b.label_rect, CLEARANCE)) ||
             Math.hypot(a.cx - b.cx, a.cy - b.cy) < DOT_RADIUS * 2 + CLEARANCE
            layout_failure(a.component.label, "component or label interferes with #{b.component.label.inspect}")
          end
        end
        dependencies.each do |line|
          points.each do |point|
            endpoint = [line.record.from, line.record.to].include?(point.component.id)
            if !endpoint && line_segments(line).any? { |segment| point_segment_distance(point.cx, point.cy, segment) < DOT_RADIUS + CLEARANCE }
              layout_failure(point.component.label, 'dot interferes with a dependency line')
            end
            if !endpoint && line_segments(line).any? { |segment| segment_rect_interfere?(segment, expand(point.label_rect, CLEARANCE)) }
              layout_failure(point.component.label, 'label interferes with a dependency line')
            end
          end
        end
        movements.each do |movement|
          if movement.x2 >= plot_right - CLEARANCE
            layout_failure(movement.record.label, 'movement cannot clear the right axis')
          end
          points.each do |point|
            next if point.component.id == movement.record.id
            if point_segment_distance(point.cx, point.cy, movement) < DOT_RADIUS + CLEARANCE ||
               segment_rect_interfere?(movement, expand(point.label_rect, CLEARANCE))
              layout_failure(movement.record.label, "movement interferes with #{point.component.label.inspect}")
            end
          end
          # Dependency and movement crossings are explicit bridge crossings in
          # the rendered grammar; labels and component dots remain protected.
        end
      end

      def line_segments(line)
        (line.points || [[line.x1, line.y1], [line.x2, line.y2]]).each_cons(2).map do |a, b|
          WardleyLine.new(x1: a[0], y1: a[1], x2: b[0], y2: b[1])
        end
      end

      def layout_failure(label, reason)
        raise LayoutError, "Wardley component #{label.inspect} #{reason}; shorten labels, spread authored visibility positions, or split the map"
      end

      def expand(rect, amount) = [rect[0] - amount, rect[1] - amount, rect[2] + amount, rect[3] + amount]
      def rect_overlap?(a, b) = a[0] < b[2] && a[2] > b[0] && a[1] < b[3] && a[3] > b[1]
      def rect_circle_interfere?(rect, x, y, radius)
        nearest_x = [[x, rect[0]].max, rect[2]].min
        nearest_y = [[y, rect[1]].max, rect[3]].min
        Math.hypot(x - nearest_x, y - nearest_y) < radius
      end

      def point_segment_distance(px, py, line)
        dx, dy = line.x2 - line.x1, line.y2 - line.y1
        return Math.hypot(px - line.x1, py - line.y1) if dx.zero? && dy.zero?
        t = [[((px - line.x1) * dx + (py - line.y1) * dy) / (dx * dx + dy * dy), 0.0].max, 1.0].min
        Math.hypot(px - (line.x1 + t * dx), py - (line.y1 + t * dy))
      end

      def segment_rect_interfere?(line, rect)
        return true if point_in_rect?(line.x1, line.y1, rect) || point_in_rect?(line.x2, line.y2, rect)
        edges = [
          WardleyLine.new(x1: rect[0], y1: rect[1], x2: rect[2], y2: rect[1]),
          WardleyLine.new(x1: rect[2], y1: rect[1], x2: rect[2], y2: rect[3]),
          WardleyLine.new(x1: rect[2], y1: rect[3], x2: rect[0], y2: rect[3]),
          WardleyLine.new(x1: rect[0], y1: rect[3], x2: rect[0], y2: rect[1])
        ]
        edges.any? { |edge| segments_intersect?(line, edge) }
      end

      def point_in_rect?(x, y, rect) = x.between?(rect[0], rect[2]) && y.between?(rect[1], rect[3])
      def orientation(ax, ay, bx, by, cx, cy) = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
      def segments_intersect?(a, b)
        o1 = orientation(a.x1, a.y1, a.x2, a.y2, b.x1, b.y1)
        o2 = orientation(a.x1, a.y1, a.x2, a.y2, b.x2, b.y2)
        o3 = orientation(b.x1, b.y1, b.x2, b.y2, a.x1, a.y1)
        o4 = orientation(b.x1, b.y1, b.x2, b.y2, a.x2, a.y2)
        return true if ((o1.positive? && o2.negative?) || (o1.negative? && o2.positive?)) &&
                       ((o3.positive? && o4.negative?) || (o3.negative? && o4.positive?))
        (o1.abs < 1e-9 && on_segment?(a.x1, a.y1, a.x2, a.y2, b.x1, b.y1)) ||
          (o2.abs < 1e-9 && on_segment?(a.x1, a.y1, a.x2, a.y2, b.x2, b.y2)) ||
          (o3.abs < 1e-9 && on_segment?(b.x1, b.y1, b.x2, b.y2, a.x1, a.y1)) ||
          (o4.abs < 1e-9 && on_segment?(b.x1, b.y1, b.x2, b.y2, a.x2, a.y2))
      end

      def on_segment?(ax, ay, bx, by, px, py)
        px.between?([ax, bx].min - 1e-9, [ax, bx].max + 1e-9) &&
          py.between?([ay, by].min - 1e-9, [ay, by].max + 1e-9)
      end

      # A dependency leaving the moving component may touch the movement's start halo,
      # but must immediately diverge and may not cross the rest of the arrow.
      def near_shared_endpoint_only?(movement, dependency)
        probe = WardleyLine.new(x1: movement.x1 + 10, y1: movement.y1, x2: movement.x2, y2: movement.y2)
        !segments_intersect?(probe, dependency)
      end

      def shared_endpoint_only?(first, second, point_by_id:, shared_id:)
        point = point_by_id.fetch(shared_id)
        trim = lambda do |line|
          other_x, other_y = if Math.hypot(line.x1 - point.cx, line.y1 - point.cy) < 0.01
            [line.x2, line.y2]
          else
            [line.x1, line.y1]
          end
          length = Math.hypot(other_x - point.cx, other_y - point.cy)
          WardleyLine.new(x1: point.cx + (other_x - point.cx) * 10.0 / length,
                          y1: point.cy + (other_y - point.cy) * 10.0 / length,
                          x2: other_x, y2: other_y)
        end
        !segments_intersect?(trim.call(first), trim.call(second))
      end
    end
  end
end
