# frozen_string_literal: true
module SlimGraphR
  module Layout
    Box = Struct.new(:node, :x, :y, :width, :height, :lines, :details, :shape, :invocations, :scopes, :statuses, :badges, :metadata,
                     :artifacts, :type_tag, :replica_badge, keyword_init: true) do
      def right = x + width
      def bottom = y + height
      def center = [x + width / 2, y + height / 2]
      def boundary(side, offset = 0)
        cx, cy = center
        case side
        when :top then [cx + offset, y + (shape == :diamond ? offset.abs * height / width.to_f : 0)]
        when :bottom then [cx + offset, bottom - (shape == :diamond ? offset.abs * height / width.to_f : 0)]
        when :left then [x + (shape == :diamond ? offset.abs * width / height.to_f : 0), cy + offset]
        when :right then [right - (shape == :diamond ? offset.abs * width / height.to_f : 0), cy + offset]
        end
      end
      def rect(padding = 0) = [x - padding, y - padding, right + padding, bottom + padding]
    end
    Route = Struct.new(:edge, :points, :label_box, :style, keyword_init: true)
    Scene = Struct.new(:boxes, :routes, :zones, :width, :height, :lifelines, :events, :activations, :fragments, :axis, :callouts,
                       :footers, :legend, :legend_rect, :legend_entries, :banners, :source_zone, :cluster, :orchestration,
                       :verticals, :effective_width, :tree_connectors, :nested_scopes, :layer_rows, :direction_indicator,
                       :pyramid_bands, :medallion_cards, :medallion_arcs, :medallion_paths,
                       :workflow_lanes, :workflow_stages, :workflow_header_height, :workflow_lane_height,
                       :workflow_grid_bottom, :workflow_return_y, :workflow_legend_rows,
                       keyword_init: true)

    module Geometry
      module_function
      def overlaps?(a, b)
        a[0] < b[2] && a[2] > b[0] && a[1] < b[3] && a[3] > b[1]
      end
      def blocked?(a, b, rect)
        if a[0] == b[0]
          a[0] > rect[0] && a[0] < rect[2] && [a[1], b[1]].min < rect[3] && [a[1], b[1]].max > rect[1]
        else
          a[1] > rect[1] && a[1] < rect[3] && [a[0], b[0]].min < rect[2] && [a[0], b[0]].max > rect[0]
        end
      end
      def parallel_conflict?(a, b, c, d, gap: 12)
        horizontal = a[1] == b[1] && c[1] == d[1]
        vertical = a[0] == b[0] && c[0] == d[0]
        return false unless horizontal || vertical
        axis, cross = horizontal ? [0, 1] : [1, 0]
        overlap = [[a[axis], b[axis]].max, [c[axis], d[axis]].max].min - [[a[axis], b[axis]].min, [c[axis], d[axis]].min].max
        overlap > 0 && (a[cross] - c[cross]).abs < gap
      end

      def crossing(a, b, c, d)
        if a[1] == b[1] && c[0] == d[0]
          x, y = c[0], a[1]
          return [x, y] if x > [a[0], b[0]].min && x < [a[0], b[0]].max && y > [c[1], d[1]].min && y < [c[1], d[1]].max
        elsif a[0] == b[0] && c[1] == d[1]
          crossing(c, d, a, b)
        end
      end

      def compact(points)
        points.uniq.each_with_object([]) do |p, result|
          if result.size >= 2
            a, b = result.last(2)
            result.pop if (a[0] == b[0] && b[0] == p[0]) || (a[1] == b[1] && b[1] == p[1])
          end
          result << p
        end
      end
    end

    # A small priority queue keeps the rectilinear visibility search bounded.
    class Heap
      def initialize = @items = []
      def push(cost, value)
        @items << [cost, value]
        i = @items.size - 1
        while i > 0
          parent = (i - 1) / 2
          break if @items[parent][0] <= cost
          @items[i], @items[parent] = @items[parent], @items[i]
          i = parent
        end
      end
      def pop
        return if @items.empty?
        top, last = @items.first, @items.pop
        unless @items.empty?
          @items[0] = last
          i = 0
          loop do
            child = 2 * i + 1
            break if child >= @items.size
            child += 1 if child + 1 < @items.size && @items[child + 1][0] < @items[child][0]
            break if @items[i][0] <= @items[child][0]
            @items[i], @items[child] = @items[child], @items[i]
            i = child
          end
        end
        top
      end
    end

    class Router
      def initialize(boxes, width, height, clearance: 24, portals: [], obstacles: [])
        @obstacles = boxes.map { |b| b.rect(clearance) } + obstacles
        @width, @height = width, height
        @segments, @corners, @portals = [], [], portals
      end

      def commit(points)
        fresh = points.each_cons(2).to_a
        if fresh.any? { |a, b| @segments.any? { |c, d| Geometry.parallel_conflict?(a, b, c, d) } }
          raise LayoutError, 'Connections crowd a node port. Split the graph to leave room for distinct arrows.'
        end
        @segments.concat(fresh)
        @corners.concat(points[1...-1])
      end

      def route(start, finish, downward: false)
        reserved = (@portals - [start, finish]) + @corners
        obstacles = @obstacles + reserved.map { |x, y| [x - 12, y - 12, x + 12, y + 12] }
        extra_x = @segments.flatten(1).flat_map { |p| [p[0] - 16, p[0], p[0] + 16] }
        extra_y = @segments.flatten(1).flat_map { |p| [p[1] - 16, p[1], p[1] + 16] }
        xs = (extra_x + [24, @width - 24, start[0], finish[0]] + obstacles.flat_map { |r| [r[0], r[2]] }).uniq.select { |x| x.between?(8, @width - 8) }.sort
        ys = (extra_y + [24, @height - 24, start[1], finish[1]] + obstacles.flat_map { |r| [r[1], r[3]] }).uniq.select { |y| y.between?(8, @height - 8) }.sort
        origin = [xs.index(start[0]), ys.index(start[1]), nil]
        goal = [xs.index(finish[0]), ys.index(finish[1])]
        costs, previous, heap = { origin => 0 }, {}, Heap.new
        heap.push(0, origin)
        while (entry = heap.pop)
          cost, current = entry
          next if cost > costs[current]
          if current.first(2) == goal
            points = []
            while current
              points << [xs[current[0]], ys[current[1]]]
              current = previous[current]
            end
            return Geometry.compact(points.reverse)
          end
          ix, iy, dir = current
          [[ix + 1, iy, :h], [ix - 1, iy, :h], [ix, iy + 1, :v], [ix, iy - 1, :v]].each do |nx, ny, nd|
            next if downward && ny < iy
            next unless nx.between?(0, xs.size - 1) && ny.between?(0, ys.size - 1)
            a, b = [xs[ix], ys[iy]], [xs[nx], ys[ny]]
            next if obstacles.any? { |r| Geometry.blocked?(a, b, r) }
            next if @segments.any? { |c, d| Geometry.parallel_conflict?(a, b, c, d) }
            if dir && dir != nd && @segments.any? { |c, d| Geometry.blocked?(c, d, [a[0] - 16, a[1] - 16, a[0] + 16, a[1] + 16]) }
              next
            end
            candidate = cost + (a[0] - b[0]).abs + (a[1] - b[1]).abs + (dir && dir != nd ? 32 : 0)
            target = [nx, ny, nd]
            next if costs.key?(target) && costs[target] <= candidate
            costs[target], previous[target] = candidate, current
            heap.push(candidate, target)
          end
        end
        raise LayoutError, 'Could not route this connection. Split the graph into smaller diagrams.'
      end
    end

    class Graph
      def initialize(diagram) = @d = diagram

      def call
        @clearance = [24, *@d.edges.filter_map { |e| Text.grid((Text.wrap(e.label, 144, 12).size * 16 + 12) / 2.0 + 12) if e.label }].max
        ranks = rank_nodes
        boxes, group_header = place_boxes(ranks)
        base_width = boxes.map(&:right).max + [80, @clearance + 32].max
        callouts, scene_width = place_org_callouts(base_width, boxes.map(&:bottom).max)
        scene_height = callouts.empty? ? boxes.map(&:bottom).max + [80, @clearance + 32].max : callouts.map { |item| item[:rect][3] }.max + 40
        scene = Scene.new(boxes: boxes, routes: [], zones: [], lifelines: [], events: [], callouts: callouts, width: scene_width, height: scene_height)
        @d.groups.each do |g|
          members = boxes.select { |b| b.node.group == g.id }
          scene.zones << { label: g.label, lines: Text.wrap(g.label, 224, 12), rect: [members.map(&:x).min - 20, members.map(&:y).min - group_header, members.map(&:right).max + 20, members.map(&:bottom).max + 20] }
        end
        connections = @d.edges.map do |edge|
          source, target = boxes.find { |b| b.node.id == edge.from }, boxes.find { |b| b.node.id == edge.to }
          outgoing = @d.edges.select { |e| e.from == edge.from }
          incoming = @d.edges.select { |e| e.to == edge.to }
          if target.shape == :merge
            axis = @d.direction == :down ? 0 : 1
            incoming = incoming.sort_by { |e| boxes.find { |b| b.node.id == e.from }.center[axis] }
          end
          # Identity matters for repeated edges: value equality would reuse a port.
          oi, ii = outgoing.index { |e| e.equal?(edge) }, incoming.index { |e| e.equal?(edge) }
          side = decision_side(source, outgoing, oi, boxes)
          start, start_stub = port(source, :out, oi, outgoing.size, side: side)
          entry_side = if incoming.size == 1 && side == :right && target.center[1] == source.center[1]
            :left
          elsif incoming.size == 1 && side == :left && target.center[1] == source.center[1]
            :right
          end
          finish, finish_stub = port(target, :in, ii, incoming.size, side: entry_side)
          { edge: edge, start: start, start_stub: start_stub, finish: finish, finish_stub: finish_stub }
        end
        portals = connections.flat_map { |connection| connection.values_at(:start_stub, :finish_stub) }
        footer_obstacles = callouts.empty? ? [] : [[0, callouts.first[:rect][1] - 24, scene.width, scene.height]]
        router = Router.new(boxes, scene.width, scene.height, clearance: @clearance, portals: portals, obstacles: footer_obstacles)
        connections.each do |connection|
          edge, start, start_stub, finish, finish_stub = connection.values_at(:edge, :start, :start_stub, :finish, :finish_stub)
          points = Geometry.compact([start] + router.route(start_stub, finish_stub) + [finish])
          router.commit(points)
          scene.routes << Route.new(edge: edge, points: points)
        end
        @crossings = scene.routes.combination(2).flat_map do |first, second|
          first.points.each_cons(2).flat_map { |a, b| second.points.each_cons(2).filter_map { |c, d| Geometry.crossing(a, b, c, d) } }
        end.uniq
        scene.routes.each do |route|
          next if !route.edge.label || route.edge.label.empty?
          route.label_box = label_box(route.edge.label, route.points, boxes, scene.routes.reject { |r| r.equal?(route) }, scene)
        end
        scene
      end

      private

      def measure_node(node)
        degree = [@d.edges.count { |e| e.from == node.id }, @d.edges.count { |e| e.to == node.id }].max
        if @d.type == :flowchart && node.kind == :merge
          return Box.new(node: node, width: 8, height: 8, lines: [], details: [], shape: :merge)
        end
        if @d.type == :flowchart && node.kind == :decision
          width = 288
          loop do
            lines = Text.wrap(node.label, width / 2 - 32)
            details = node.detail ? Text.wrap(node.detail, width / 2 - 32, 12) : []
            content_height = lines.size * 20 + details.size * 16 + (details.empty? ? 0 : 8)
            if content_height <= width / 4 - 24 && width / 2 >= degree * 16 + 32
              return Box.new(node: node, width: width, height: width / 2, lines: lines, details: details, shape: :diamond)
            end
            width += 32
          end
        end
        width = [@d.type == :org_chart ? 240 : 224, Text.grid(degree * 16 + 32)].max
        lines = Text.wrap(node.label, width - 40)
        details = node.detail ? Text.wrap(node.detail, width - 40, 12) : []
        invocations = @d.type == :org_chart && node.invoke ? Text.wrap(node.invoke, width - 40, 12, font: :mono) : []
        scopes = @d.type == :org_chart && node.scope ? Text.wrap(node.scope, width - 40, 12) : []
        statuses = @d.type == :org_chart && node.unavailable ? ['SETUP NEEDED'] : []
        terminator = @d.type == :flowchart && %i[start finish].include?(node.kind)
        sections = [[lines, 20], [invocations, 16], [scopes, 16], [details, 16], [statuses, 16]].reject { |content, _| content.empty? }
        content_height = sections.sum { |content, leading| content.size * leading } + [sections.size - 1, 0].max * 5
        height = [terminator ? 64 : 88, Text.grid(content_height + 32), Text.grid(degree * 16 + 32)].max
        Box.new(node: node, width: width, height: height, lines: lines, details: details, invocations: invocations,
                scopes: scopes, statuses: statuses, shape: terminator ? :terminator : :rectangle)
      end

      def place_org_callouts(base_width, graph_bottom)
        records = @d.rules + @d.setup_gaps
        return [[], base_width] unless @d.type == :org_chart && !records.empty?
        gap = 16
        minimum_card_width = 272
        width = [base_width, 80 + records.size * minimum_card_width + (records.size - 1) * gap].max
        card_width = (width - 80 - (records.size - 1) * gap) / records.size.to_f
        # Leave enough space for the largest connector stub/label clearance before the footer barrier.
        top = Text.grid(graph_bottom + @clearance + 40)
        callouts = records.each_with_index.map do |record, index|
          owner = @d.nodes.find { |node| node.id == record.owner }
          lines = Text.wrap(record.label, card_width - 40, 13)
          prefix = record.is_a?(OrgSetupGap) ? 'For: ' : record.kind == :escalation ? 'To: ' : 'By: '
          owner_lines = Text.wrap(owner.label, card_width - 40 - Text.width(prefix, 12), 12)
          invoke_lines = owner.invoke ? Text.wrap(owner.invoke, card_width - 40, 12, font: :mono) : []
          height = Text.grid(52 + lines.size * 18 + owner_lines.size * 16 + invoke_lines.size * 16)
          x = Text.grid(40 + index * (card_width + gap))
          { rule: record.is_a?(OrgRule) ? record : nil, setup_gap: record.is_a?(OrgSetupGap) ? record : nil,
            owner: owner, lines: lines, owner_lines: owner_lines, invoke_lines: invoke_lines,
            rect: [x, top, Text.grid(x + card_width), top + height] }
        end
        [callouts, width]
      end

      def place_boxes(ranks)
        boxes = @d.nodes.map { |node| measure_node(node) }
        max_width, max_height = boxes.map(&:width).max, boxes.map(&:height).max
        group_header = [40, *@d.groups.map { |g| Text.wrap(g.label, 224, 12).size * 16 + 20 }].max
        grouped = @d.nodes.group_by(&:group)
        offsets, lane_sizes, offset = {}, {}, 0
        grouped.each do |group, members|
          size = members.group_by { |n| ranks[n.id] }.values.map(&:size).max
          offsets[group], lane_sizes[group] = offset, size
          offset += size
        end
        margin = [64, @clearance + 32].max
        cursor = @d.direction == :right ? margin : [group_header + 32, margin].max
        positions = {}
        boxes.group_by { |b| ranks[b.node.id] }.sort.each do |rank, members|
          positions[rank] = cursor
          cursor += members.map { |b| @d.direction == :right ? b.width : b.height }.max + (@d.direction == :right ? 128 : 104)
        end
        counts = Hash.new(0)
        boxes.each do |box|
          rank, group = ranks[box.node.id], box.node.group
          peers = grouped[group].count { |n| ranks[n.id] == rank }
          cross = offsets[group] + counts[[rank, group]] + (lane_sizes[group] - peers) / 2.0
          counts[[rank, group]] += 1
          if @d.direction == :right
            box.x = positions[rank]
            box.y = Text.grid([group_header + 32, margin].max + cross * (max_height + group_header + 32) + (max_height - box.height) / 2.0)
          else
            box.x = Text.grid(margin + cross * (max_width + 80) + (max_width - box.width) / 2.0)
            box.y = positions[rank]
          end
        end
        arrange_decision_branches(boxes, ranks) if @d.type == :flowchart && @d.direction == :down && @d.groups.empty?
        [boxes, group_header]
      end

      def arrange_decision_branches(boxes, ranks)
        boxes.select { |box| box.shape == :diamond }.each do |decision|
          next unless boxes.count { |b| ranks[b.node.id] == ranks[decision.node.id] } == 1
          exits = @d.edges.select { |e| e.from == decision.node.id }
          next unless exits.size == 2
          yes = exits.find { |e| e.label.match?(/\A(yes|true|approved)\z/i) }
          no = exits.find { |e| e.label.match?(/\A(no|false|needs changes|not yet)\z/i) }
          next unless yes && no && yes.to != no.to
          positive, negative = [yes, no].map { |edge| boxes.find { |b| b.node.id == edge.to } }
          next unless [positive, negative].all? { |b| ranks[b.node.id] == ranks[decision.node.id] + 1 && @d.edges.count { |e| e.to == b.node.id } == 1 && b.shape != :diamond }
          next if positive.height > decision.height
          left, right = [positive.center[0], negative.center[0]].sort
          positive.x, negative.x = right - positive.width / 2, left - negative.width / 2
          positive.y = Text.grid(decision.center[1] - positive.height / 2.0)
          decision.x = left - decision.width / 2
          child = decision
          loop do
            incoming = @d.edges.select { |e| e.to == child.node.id }
            break unless incoming.size == 1
            parent = boxes.find { |b| b.node.id == incoming.first.from }
            break unless ranks[parent.node.id] < ranks[child.node.id] && boxes.count { |b| ranks[b.node.id] == ranks[parent.node.id] } == 1 && @d.edges.count { |e| e.from == parent.node.id } == 1
            parent.x = left - parent.width / 2
            child = parent
          end
        end
      end

      def rank_nodes
        visited, active, order, backwards = {}, {}, [], []
        visit = lambda do |id|
          return if visited[id]
          active[id] = true
          @d.edges.select { |e| e.from == id }.each do |edge|
            if active[edge.to]
              backwards << edge
            else
              visit.call(edge.to)
            end
          end
          active.delete(id)
          visited[id] = true
          order << id
        end
        @d.nodes.each { |n| visit.call(n.id) }
        raise Error, 'An org chart cannot contain a cycle' if @d.type == :org_chart && !backwards.empty?
        ranks = @d.nodes.to_h { |n| [n.id, 0] }
        order.reverse.each do |id|
          @d.edges.select { |e| e.from == id && !backwards.include?(e) }.each do |edge|
            ranks[edge.to] = [ranks[edge.to], ranks[id] + 1].max
          end
        end
        ranks
      end

      def port(box, role, index, total, side: nil)
        if box.shape == :merge
          side = if role == :out
            @d.direction == :right ? :right : :bottom
          else
            (@d.direction == :right ? (total == 2 ? %i[top bottom] : %i[top left bottom]) : (total == 2 ? %i[left right] : %i[left top right]))[index]
          end
          delta = 0
        elsif side
          delta = 0
        else
          delta = Text.grid((index - (total - 1) / 2.0) * 16)
          side = @d.direction == :right ? (role == :out ? :right : :left) : (role == :out ? :bottom : :top)
        end
        point = box.boundary(side, delta)
        # The stub clears the layout envelope, including a diamond's empty corners.
        stub = case side
        when :right then [box.right + @clearance + 8, point[1]]
        when :left then [box.x - @clearance - 8, point[1]]
        when :bottom then [point[0], box.bottom + @clearance + 8]
        when :top then [point[0], box.y - @clearance - 8]
        end
        [point, stub]
      end

      def decision_side(box, outgoing, index, boxes)
        return unless box.shape == :diamond
        # Conventional Yes/No labels get conventional ports; other guards use distinct sides.
        positive = outgoing.index { |e| e.label.match?(/\A(yes|true|approved)\z/i) }
        negative = outgoing.index { |e| e.label.match?(/\A(no|false|needs changes|not yet)\z/i) }
        sides = {}
        sides[positive] = :right if positive
        sides[negative] = :bottom if negative
        available = (@d.direction == :down ? %i[left bottom right] : %i[top right bottom]) - sides.values
        outgoing.each_with_index do |edge, i|
          next if sides[i]
          target = boxes.find { |b| b.node.id == edge.to }
          if @d.direction == :down
            preferred = target.center[0] < box.center[0] ? :left : target.center[0] > box.center[0] ? :right : :bottom
          else
            preferred = target.center[1] < box.center[1] ? :top : target.center[1] > box.center[1] ? :bottom : :right
          end
          sides[i] = available.include?(preferred) ? preferred : available.first
          available.delete(sides[i])
        end
        sides.fetch(index)
      end

      def label_box(label, points, boxes, routes, scene)
        lines = Text.wrap(label, 144, 12)
        w, h = Text.grid(lines.map { |l| Text.width(l, 12) }.max + 20), Text.grid(lines.size * 16 + 12)
        segments = points.each_cons(2).sort_by { |a, b| -((a[0] - b[0]).abs + (a[1] - b[1]).abs) }
        segments.each do |a, b|
          [0.5, 0.65, 0.35, 0.8, 0.2].each do |fraction|
            cx, cy = Text.grid(a[0] + (b[0] - a[0]) * fraction), Text.grid(a[1] + (b[1] - a[1]) * fraction)
            offsets = a[1] == b[1] ? [[0, -h / 2 - 8], [0, h / 2 + 8]] : [[w / 2 + 8, 0], [-w / 2 - 8, 0]]
            offsets.each do |dx, dy|
              x, y = cx + dx, cy + dy
              rect = [x - w / 2, y - h / 2, x + w / 2, y + h / 2]
              next if rect[0] < 8 || rect[1] < 8 || rect[2] > scene.width - 8 || rect[3] > scene.height - 8
              next if boxes.any? { |box| Geometry.overlaps?(rect, box.rect(8)) }
              # A hop reaches eight pixels from the straight path; reserve eight more for the label.
              next if @crossings.any? { |px, py| Geometry.overlaps?(rect, [px - 16, py - 16, px + 16, py + 16]) }
              clearance_rect = [rect[0] - 8, rect[1] - 8, rect[2] + 8, rect[3] + 8]
              next if points.each_cons(2).any? { |p, q| Geometry.blocked?(p, q, clearance_rect) }
              next if routes.any? { |r| r.points.each_cons(2).any? { |p, q| Geometry.blocked?(p, q, clearance_rect) } }
              next if routes.any? { |r| r.label_box && Geometry.overlaps?(rect, r.label_box[:rect]) }
              return { rect: rect, lines: lines }
            end
          end
        end
        raise LayoutError, "No space for edge label #{label.inspect}. Shorten the label or split the diagram."
      end
    end
  end
end
