# frozen_string_literal: true
module SlimGraphR
  module Layout
    StateRoute = Struct.new(
      :transition, :start, :control1, :control2, :finish, :label_box, :kind, :samples,
      keyword_init: true
    )
    StateScene = Struct.new(:boxes, :routes, :width, :height, :entry, :finals, keyword_init: true)

    # Bounded lifecycle layout: one simple multi-state feedback cycle and one loop per state.
    class State
      SAMPLE_STEPS = 128
      CURVE_CLEARANCE = 16
      RIGHT_RANK_GAP = 240
      RIGHT_MARGIN = 72
      FINAL_MARKER_OFFSET = 56

      def initialize(diagram) = @d = diagram

      def call
        feedback = feedback_transition
        spine = @d.transitions.reject { |item| item.from == item.to || item.equal?(feedback) }
        ranks = ranks_for(spine)
        boxes = place_states(ranks)
        scene = StateScene.new(boxes: boxes, routes: [], width: 0, height: 0)
        scene.entry = entry_marker(boxes)
        scene.finals = final_markers(boxes)
        scene.width = [boxes.map(&:right).max + RIGHT_MARGIN, scene.finals.map { |item| item[:outer][0] + 24 }.max || 0].max
        scene.height = [boxes.map(&:bottom).max + 196, scene.finals.map { |item| item[:outer][1] + 24 }.max || 0].max
        scene.width = [scene.width, scene.entry[:dot][0] + 24].max
        scene.height = [scene.height, scene.entry[:dot][1] + 24].max

        # Reserve outside lanes first; forward routes must respect loops and feedback,
        # including those that share a state. Assign labels only after every curve exists.
        @marker_rects = marker_rects(scene)
        @reserved_routes = []
        ordered = @d.transitions.each_with_index.sort_by do |transition, _|
          transition.from == transition.to ? 0 : transition.equal?(feedback) ? 1 : 2
        end
        ordered.each do |transition, index|
          route = if transition.from == transition.to
            self_loop(transition, boxes, index)
          elsif transition.equal?(feedback)
            feedback_route(transition, boxes, index)
          else
            forward_route(transition, boxes, ranks, index)
          end
          unless route_clear?(route, boxes)
            raise LayoutError, "Could not separate state transition #{transition.label.inspect} from another curve or marker. Split the state machine."
          end
          @reserved_routes << route
        end
        scene.routes = @d.transitions.map { |transition| @reserved_routes.find { |route| route.transition.equal?(transition) } }
        labels = []
        @reserved_routes.each do |route|
          route.label_box = label_box(route, boxes, labels, scene)
          labels << route.label_box[:rect]
        end
        bounds = scene.routes.flat_map(&:samples)
        unless bounds.all? { |x, y| x.between?(8, scene.width - 8) && y.between?(8, scene.height - 8) }
          raise LayoutError, 'A state transition escaped the bounded scene. Shorten labels or split the state machine.'
        end
        scene
      end

      private

      def measure(state)
        width = 224
        lines = Text.wrap(state.label, width - 40)
        details = state.detail ? state.detail.split("\n").flat_map { |line| Text.wrap(line, width - 40, 12, font: :mono) } : []
        if details.size > 3
          raise LayoutError, "State detail #{state.detail.inspect} does not fit the measured state card; shorten it or split the state machine"
        end
        height = [72, Text.grid(lines.size * 20 + details.size * 16 + 32)].max
        Box.new(node: state, width: width, height: height, lines: lines, details: details, shape: :state)
      end

      def place_states(ranks)
        boxes = @d.states.map { |state| measure(state) }
        max_width = boxes.map(&:width).max
        max_height = boxes.map(&:height).max
        top = 196
        left = @d.direction == :right ? 128 : 320
        grouped = boxes.group_by { |box| ranks.fetch(box.node.id) }
        grouped.each do |rank, peers|
          peers.each_with_index do |box, index|
            if @d.direction == :right
              box.x = left + rank * (max_width + RIGHT_RANK_GAP)
              box.y = top + index * (max_height + 160)
            else
              box.x = left + index * (max_width + 160)
              box.y = top + rank * (max_height + 224)
            end
          end
        end
        boxes
      end

      def feedback_transition
        candidates = @d.transitions.reject { |item| item.from == item.to }
        candidates.find do |candidate|
          reachable_without(candidate).sort == @d.states.map(&:id).sort &&
            path_exists?(candidate.to, candidate.from, candidates.reject { |item| item.equal?(candidate) })
        end
      end

      def reachable_without(omitted)
        seen, pending = [], [@d.initial_state]
        edges = @d.transitions.reject { |item| item.equal?(omitted) || item.from == item.to }
        until pending.empty?
          id = pending.shift
          next if seen.include?(id)
          seen << id
          pending.concat(edges.select { |item| item.from == id }.map(&:to))
        end
        seen
      end

      def path_exists?(from, to, edges)
        seen, pending = [], [from]
        until pending.empty?
          id = pending.shift
          return true if id == to
          next if seen.include?(id)
          seen << id
          pending.concat(edges.select { |item| item.from == id }.map(&:to))
        end
        false
      end

      def ranks_for(edges)
        ranks = @d.states.to_h { |item| [item.id, item.id == @d.initial_state ? 0 : nil] }
        @d.states.size.times do
          edges.each do |item|
            next unless ranks[item.from]
            proposed = ranks[item.from] + 1
            ranks[item.to] = proposed if !ranks[item.to] || proposed > ranks[item.to]
          end
        end
        missing = ranks.select { |_, rank| rank.nil? }.keys
        raise LayoutError, "Could not place states on the lifecycle spine: #{missing.join(', ')}" unless missing.empty?
        ranks
      end

      def entry_marker(boxes)
        box = find_box(boxes, @d.initial_state)
        if @d.direction == :right
          dot = [box.x - 64, box.center[1]]
          finish = [box.x, box.center[1]]
        else
          dot = [box.center[0], box.y - 64]
          finish = [box.center[0], box.y]
        end
        { state: @d.initial_state, dot: dot, finish: finish }
      end

      def final_markers(boxes)
        @d.final_states.map do |id|
          box = find_box(boxes, id)
          if @d.direction == :right
            start = [box.right, box.center[1]]
            outer = [box.right + FINAL_MARKER_OFFSET, box.center[1]]
          else
            start = [box.center[0], box.bottom]
            outer = [box.center[0], box.bottom + 64]
          end
          { state: id, start: start, outer: outer }
        end
      end

      def forward_route(transition, boxes, ranks, index)
        source, target = find_box(boxes, transition.from), find_box(boxes, transition.to)
        outgoing = @d.transitions.reject { |item| item.from == item.to }.select { |item| item.from == transition.from }
        incoming = @d.transitions.reject { |item| item.from == item.to }.select { |item| item.to == transition.to }
        oi, ii = outgoing.index(transition), incoming.index(transition)
        start = state_port(source, :out, oi, outgoing.size)
        finish = state_port(target, :in, ii, incoming.size)
        span = ranks.fetch(transition.to) - ranks.fetch(transition.from)
        offsets = span > 1 ? [-(112 + index * 28), 112 + index * 28, -(192 + index * 28), 192 + index * 28] : [0, -96, 96]
        offsets.unshift(-64) if @d.direction == :down && self_loop_on?(target)
        controls = offsets.lazy.map { |offset| curve_controls(start, finish, offset) }.find do |c1, c2|
          route_clear?(build_route(transition, start, c1, c2, finish, :forward), boxes)
        end
        raise LayoutError, "Could not route state transition #{transition.label.inspect}. Split the state machine." unless controls
        build_route(transition, start, *controls, finish, :forward)
      end

      def feedback_route(transition, boxes, index)
        source, target = find_box(boxes, transition.from), find_box(boxes, transition.to)
        if @d.direction == :right
          # The left shoulder stays outside a centered self-loop on either state.
          start = [source.x + 24, source.y]
          finish = [target.x + 24, target.y]
          lane = 36 + index * 12
          c1, c2 = [start[0], lane], [finish[0], lane]
        else
          start = [source.x, source.center[1]]
          finish = [target.x, target.center[1]]
          lane = 36 + index * 12
          c1, c2 = [lane, start[1]], [lane, finish[1]]
        end
        route = build_route(transition, start, c1, c2, finish, :feedback)
        unless clear_curve?(route.samples, boxes, source, target)
          raise LayoutError, "Could not reserve an outside feedback lane for #{transition.label.inspect}. Split the state machine."
        end
        route
      end

      def self_loop(transition, boxes, index)
        box = find_box(boxes, transition.from)
        # Downward incoming transitions occupy the middle of the top edge.
        # Keep their neighboring self-loop on the right shoulder.
        cx = box.center[0] + (@d.direction == :down ? 68 : 0)
        half_port = @d.direction == :down ? 28 : 36
        reach = @d.direction == :down ? 72 : 96
        start, finish = [cx + half_port, box.y], [cx - half_port, box.y]
        lift = 88 + index * 4
        c1, c2 = [cx + reach, box.y - lift], [cx - reach, box.y - lift]
        build_route(transition, start, c1, c2, finish, :self_loop)
      end

      def curve_controls(start, finish, offset)
        if @d.direction == :right
          reach = [(finish[0] - start[0]).abs * 0.34, 56].max
          [[start[0] + reach, start[1] + offset], [finish[0] - reach, finish[1] + offset]]
        else
          reach = [(finish[1] - start[1]).abs * 0.34, 56].max
          [[start[0] + offset, start[1] + reach], [finish[0] + offset, finish[1] - reach]]
        end
      end

      def state_port(box, role, index, count)
        delta = Text.grid((index - (count - 1) / 2.0) * 20)
        if @d.direction == :right
          role == :out ? [box.right, box.center[1] + delta] : [box.x, box.center[1] + delta]
        else
          incoming_offset = self_loop_on?(box) ? -64 : 0
          role == :out ? [box.center[0] + delta, box.bottom] : [box.center[0] + delta + incoming_offset, box.y]
        end
      end

      def self_loop_on?(box)
        @d.transitions.any? { |item| item.from == box.node.id && item.to == box.node.id }
      end

      def build_route(transition, start, control1, control2, finish, kind)
        StateRoute.new(
          transition: transition, start: start, control1: control1, control2: control2, finish: finish,
          kind: kind, samples: sample_curve(start, control1, control2, finish)
        )
      end

      def sample_curve(start, control1, control2, finish)
        # ||B''|| / (8 n²) bounds the error between a cubic and its chords.
        # Increase the resolution for unusually tall state labels as well.
        curvature = [[start, control1, control2], [control1, control2, finish]].map do |a, b, c|
          Math.hypot(a[0] - 2 * b[0] + c[0], a[1] - 2 * b[1] + c[1])
        end.max
        steps = [SAMPLE_STEPS, Math.sqrt(3 * curvature).ceil].max
        (0..steps).map do |step|
          t = step.fdiv(steps)
          u = 1.0 - t
          [0, 1].map do |axis|
            u**3 * start[axis] + 3 * u**2 * t * control1[axis] + 3 * u * t**2 * control2[axis] + t**3 * finish[axis]
          end
        end
      end

      def clear_curve?(samples, boxes, source, target)
        return false if boxes.any? do |box|
          !box.equal?(source) && !box.equal?(target) && curve_near_rect?(samples, box.rect(8), 1)
        end
        samples[1...-1].none? do |point|
          boxes.any? do |box|
            next false unless box.equal?(source) || box.equal?(target)
            x, y, right, bottom = box.rect
            point[0] > x && point[0] < right && point[1] > y && point[1] < bottom
          end
        end
      end

      def marker_rects(scene)
        x, y = scene.entry[:dot]
        fx, fy = scene.entry[:finish]
        rects = [[[x, fx].min - 8, [y, fy].min - 8, [x, fx].max + 8, [y, fy].max + 8]]
        scene.finals.each do |marker|
          x, y = marker[:start]
          fx, fy = marker[:outer]
          rects << [[x, fx].min - 10, [y, fy].min - 10, [x, fx].max + 10, [y, fy].max + 10]
        end
        rects
      end

      def route_clear?(route, boxes)
        source = find_box(boxes, route.transition.from)
        target = find_box(boxes, route.transition.to)
        return false unless clear_curve?(route.samples, boxes, source, target)
        return false if @marker_rects.any? { |rect| curve_near_rect?(route.samples, rect, 2) }
        @reserved_routes.none? { |other| curves_near?(route.samples, other.samples, CURVE_CLEARANCE) }
      end

      # Cubics are flattened into short segments, with a conservative clearance
      # larger than their subpixel approximation error, stroke and 6x6 arrowhead.
      # Segment intersection catches crossings even when no sampled point is close.
      def curves_near?(first, second, gap)
        first.each_cons(2).any? do |a, b|
          second.each_cons(2).any? { |c, d| segments_near?(a, b, c, d, gap) }
        end
      end

      def segments_near?(a, b, c, d, gap)
        return false if [a[0], b[0]].max + gap < [c[0], d[0]].min || [c[0], d[0]].max + gap < [a[0], b[0]].min ||
          [a[1], b[1]].max + gap < [c[1], d[1]].min || [c[1], d[1]].max + gap < [a[1], b[1]].min
        cross = ->(p, q, r) { (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0]) }
        return true if cross.call(a, b, c) * cross.call(a, b, d) <= 0 && cross.call(c, d, a) * cross.call(c, d, b) <= 0
        [point_segment_distance(a, c, d), point_segment_distance(b, c, d),
         point_segment_distance(c, a, b), point_segment_distance(d, a, b)].min < gap
      end

      def point_segment_distance(point, a, b)
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = dx * dx + dy * dy
        t = length.zero? ? 0 : [[((point[0] - a[0]) * dx + (point[1] - a[1]) * dy) / length, 0].max, 1].min
        Math.hypot(point[0] - a[0] - t * dx, point[1] - a[1] - t * dy)
      end

      def curve_near_rect?(samples, rect, gap)
        left, top, right, bottom = rect
        corners = [[left, top], [right, top], [right, bottom], [left, bottom]]
        return true if samples.any? { |x, y| x.between?(left, right) && y.between?(top, bottom) }
        curves_near?(samples, corners + [corners.first], gap)
      end

      def curve_rect_distance(samples, rect)
        left, top, right, bottom = rect
        corners = [[left, top], [right, top], [right, bottom], [left, bottom]]
        endpoint_distance = samples.map do |x, y|
          Math.hypot([left - x, 0, x - right].max, [top - y, 0, y - bottom].max)
        end.min
        corner_distance = samples.each_cons(2).map do |a, b|
          corners.map { |corner| point_segment_distance(corner, a, b) }.min
        end.min
        [endpoint_distance, corner_distance].min
      end

      def label_box(route, boxes, existing, scene)
        lines = Text.wrap(route.transition.label, 200, 12, font: :mono)
        width = Text.grid(lines.map { |line| Text.width(line, 12, font: :mono) }.max + 20)
        height = Text.grid(lines.size * 16 + 12)
        midpoint = (route.samples.size - 1) / 2
        candidates = case route.kind
        when :self_loop
          loop_x = route.samples[midpoint][0]
          loop_y = route.samples.map(&:last).min - height / 2 - 10
          [[loop_x, loop_y]]
        when :feedback
          if @d.direction == :right
            [[route.samples[midpoint][0], route.samples.map(&:last).min - height / 2 - 8],
             [route.samples[midpoint][0], route.samples.map(&:last).min + height / 2 + 8]]
          else
            [[route.samples.map(&:first).min - width / 2 - 8, route.samples[midpoint][1]],
             [route.samples.map(&:first).min + width / 2 + 8, route.samples[midpoint][1]]]
          end
        else
          [0.5, 0.35, 0.65, 0.25, 0.75].flat_map do |fraction|
            point = route.samples[((route.samples.size - 1) * fraction).round]
            [12, 24].flat_map do |gap|
              @d.direction == :right ? [[point[0], point[1] - height / 2 - gap], [point[0], point[1] + height / 2 + gap]] :
                [[point[0] + width / 2 + gap, point[1]], [point[0] - width / 2 - gap, point[1]]]
            end
          end
        end
        candidates.each do |cx, cy|
          rect = [Text.grid(cx - width / 2), Text.grid(cy - height / 2), Text.grid(cx + width / 2), Text.grid(cy + height / 2)]
          next if rect[0] < 8 || rect[1] < 8 || rect[2] > scene.width - 8 || rect[3] > scene.height - 8
          next if boxes.any? { |box| Geometry.overlaps?(rect, box.rect(8)) }
          next if existing.any? { |other| Geometry.overlaps?(rect, other) }
          next if @marker_rects.any? { |other| Geometry.overlaps?(rect, other) }
          # Keep each label beside its own curve, with more space to every other
          # transition. Opaque paper masks must never hide a curve or arrowhead.
          next if curve_near_rect?(route.samples, rect, 3)
          own_distance = curve_rect_distance(route.samples, rect)
          next if own_distance > 28
          next if scene.routes.any? { |other| !other.equal?(route) && curve_near_rect?(other.samples, rect, [22, own_distance + 8].max) }
          return { rect: rect, lines: lines }
        end
        raise LayoutError, "No clear measured label box for state transition #{route.transition.label.inspect}. Shorten the label or split the state machine."
      end

      def find_box(boxes, id) = boxes.find { |box| box.node.id == id }
    end
  end
end
