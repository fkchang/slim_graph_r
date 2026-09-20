# frozen_string_literal: true
module SlimGraphR
  module Layout
    class Dependency
      NODE_WIDTH = 160
      NODE_HEIGHT = 56
      RANK_STEP = 120
      COLUMN_STEP = 240
      MARGIN = 64

      def initialize(diagram) = @d = diagram

      def call
        forward = @d.edges.reject(&:cycle)
        ranks = rank_nodes(forward)
        rank_density = forward.group_by { |edge| [ranks.fetch(edge.from), ranks.fetch(edge.to)] }.values.map(&:size).max.to_i
        @rank_step = rank_density >= 4 ? 168 : RANK_STEP
        boxes = place_boxes(ranks)
        content_width = [boxes.map(&:right).max + MARGIN, 320].max
        cycle_edge = @d.edges.find(&:cycle)
        scene_width = content_width + (cycle_edge ? 112 : 0)
        scene = Scene.new(boxes: boxes, routes: [], zones: [], lifelines: [], events: [], activations: [],
                          fragments: [], callouts: [], width: scene_width, height: boxes.map(&:bottom).max + MARGIN)
        route_forward(scene, forward, content_width)
        route_cycle(scene, cycle_edge, content_width) if cycle_edge
        scene
      end

      private

      def rank_nodes(relationships)
        indegree = @d.nodes.to_h { |node| [node.id, 0] }
        relationships.each { |edge| indegree[edge.to] += 1 }
        queue = @d.nodes.map(&:id).select { |id| indegree[id].zero? }
        ranks = @d.nodes.to_h { |node| [node.id, 0] }
        until queue.empty?
          id = queue.shift
          relationships.select { |edge| edge.from == id }.each do |edge|
            ranks[edge.to] = [ranks[edge.to], ranks[id] + 1].max
            indegree[edge.to] -= 1
            queue << edge.to if indegree[edge.to].zero?
          end
        end
        ranks
      end

      def place_boxes(ranks)
        rows = @d.nodes.group_by { |node| ranks.fetch(node.id) }
        widest = rows.values.map(&:size).max
        rows.flat_map do |rank, nodes|
          row_width = (nodes.size - 1) * COLUMN_STEP + NODE_WIDTH
          full_width = (widest - 1) * COLUMN_STEP + NODE_WIDTH
          start_x = MARGIN + (full_width - row_width) / 2
          nodes.each_with_index.map do |node, index|
            fan_in = @d.edges.count { |edge| edge.to == node.id }
            metadata = node.kind == :external ? ["#{node.version} · #{node.registry}"] : []
            Box.new(node: node, x: start_x + index * COLUMN_STEP, y: 56 + rank * @rank_step,
                    width: NODE_WIDTH, height: NODE_HEIGHT, lines: [node.label], details: [],
                    badges: ["#{fan_in} in"], metadata: metadata, shape: :dependency)
          end
        end
      end

      def route_forward(scene, relationships, content_width)
        connections = relationships.map do |edge|
          source = scene.boxes.find { |box| box.node.id == edge.from }
          target = scene.boxes.find { |box| box.node.id == edge.to }
          outgoing = relationships.select { |item| item.from == edge.from }
          incoming = relationships.select { |item| item.to == edge.to }
          oi = outgoing.index { |item| item.equal?(edge) }
          ii = incoming.index { |item| item.equal?(edge) }
          source_count = @d.edges.count { |item| item.from == edge.from }
          start = source.boundary(:bottom, fan_offset(oi, source_count, :out))
          finish = target.boundary(:top, fan_offset(ii, incoming.size, :in))
          { edge: edge, start: start, start_stub: [start[0], start[1] + 24],
            finish: finish, finish_stub: [finish[0], finish[1] - 24] }
        end
        obstacles = scene.boxes.map { |box| box.rect(16) } + [[0, 0, content_width, 32]]
        committed = []
        # Long fan-in routes claim inter-rank lanes first; short vertical links
        # then fit between them. This is deterministic and avoids letting a
        # local edge seal the only corridor for a spanning dependency.
        connections.sort_by { |item| [-(item[:start][0] - item[:finish][0]).abs, item[:edge].from, item[:edge].to] }.each do |connection|
          edge, start, start_stub, finish, finish_stub = connection.values_at(:edge, :start, :start_stub, :finish, :finish_stub)
          begin
            middle = dependency_lane_route(start_stub, finish_stub, obstacles, committed, content_width, scene.height)
            points = Geometry.compact([start] + middle + [finish])
            committed.concat(points.each_cons(2).to_a)
          rescue LayoutError => error
            raise LayoutError, "Could not route dependency #{edge.from} -> #{edge.to}: #{error.message}"
          end
          scene.routes << Route.new(edge: edge, points: points)
        end
      end

      def dependency_lane_route(start, finish, obstacles, committed, width, height)
        x_lanes = ([24, width - 24, start[0], finish[0]] + (24..(width - 24)).step(16).to_a + obstacles.flat_map { |rect| [rect[0] - 16, rect[2] + 16] }).uniq
          .select { |x| x.between?(16, width - 16) }.sort
        y_lanes = ([start[1], finish[1]] + start[1].step(finish[1], 16).to_a + obstacles.flat_map { |rect| [rect[1] - 16, rect[3] + 16] }).uniq
          .select { |y| y.between?(start[1], finish[1]) && y.between?(32, height - 16) }.sort
        candidates = []
        candidates << [start, finish] if start[0] == finish[0]
        y_lanes.each { |y| candidates << [start, [start[0], y], [finish[0], y], finish] }
        x_lanes.each { |x| candidates << [start, [x, start[1]], [x, finish[1]], finish] }
        valid = candidates.map { |points| Geometry.compact(points) }.uniq.select do |points|
          points.each_cons(2).all? do |a, b|
            b[1] >= a[1] && obstacles.none? { |rect| Geometry.blocked?(a, b, rect) } &&
              committed.none? { |c, d| Geometry.parallel_conflict?(a, b, c, d) }
          end
        end
        route = valid.min_by do |points|
          length = points.each_cons(2).sum { |a, b| (a[0] - b[0]).abs + (a[1] - b[1]).abs }
          [length + (points.size - 2) * 32, points.flatten]
        end
        raise LayoutError, 'Could not route this connection. Split the graph into smaller diagrams.' unless route
        route
      end

      def route_cycle(scene, edge, content_width)
        source = scene.boxes.find { |box| box.node.id == edge.from }
        target = scene.boxes.find { |box| box.node.id == edge.to }
        outside_x = content_width + 40
        source_count = @d.edges.count { |item| item.from == edge.from }
        start = source.boundary(:bottom, fan_offset(source_count - 1, source_count, :out))
        finish = target.boundary(:right)
        top_y = finish[1]
        label_left = outside_x - 72
        label_right = outside_x - 24
        label_box = { lines: ['CYCLE'], rect: [label_left, top_y - 28, label_right, top_y - 8], cycle: true }
        points = [24, 40, 48, 16, 12, 52].filter_map do |offset|
          departure_y = source.bottom + offset
          candidate = [start, [start[0], departure_y], [outside_x, departure_y], [outside_x, top_y], finish]
          candidate if clear_cycle?(scene, candidate, label_box[:rect])
        end.first
        unless points
          raise LayoutError, "Could not route dependency cycle #{edge.from} -> #{edge.to} with clear ports and label. Split the graph into smaller diagrams."
        end
        scene.routes << Route.new(edge: edge, points: points, label_box: label_box)
      end

      def clear_cycle?(scene, points, label)
        segments = points.each_cons(2).to_a
        crowded = scene.boxes.any? do |box|
          Geometry.overlaps?(label, box.rect) ||
            segments.any? { |a, b| Geometry.blocked?(a, b, box.rect) }
        end
        crowded ||= scene.routes.any? do |route|
          route.points.each_cons(2).any? do |a, b|
            Geometry.blocked?(a, b, label) ||
              segments.any? { |c, d| Geometry.parallel_conflict?(a, b, c, d) }
          end
        end
        !crowded
      end

      def fan_offset(index, total, role)
        step = role == :out ? [48, 112.0 / [total - 1, 1].max].min : 16
        Text.grid((index - (total - 1) / 2.0) * step)
      end
    end
  end
end
