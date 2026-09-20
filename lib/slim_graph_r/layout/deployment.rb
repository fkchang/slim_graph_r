# frozen_string_literal: true
module SlimGraphR
  module Layout
    class Deployment
      MARGIN = 56
      ZONE_TOP = 24
      ZONE_HEADER = 40
      ZONE_PADDING = 20
      ZONE_GAP = 96
      NODE_GAP = 64
      NODE_MIN_WIDTH = 248
      CHIP_HEIGHT = 24
      CHIP_GAP = 8
      ROUTE_CLEARANCE = 16

      def initialize(diagram) = @d = diagram

      def call
        boxes = @d.nodes.map { |node| measure_node(node) }
        zones = place_zones(boxes)
        width = zones.last[:rect][2] + MARGIN
        height = zones.map { |zone| zone[:rect][3] }.max + 40
        scene = Scene.new(
          boxes: boxes, routes: [], zones: zones, lifelines: [], events: [], activations: [],
          fragments: [], callouts: [], width: width, height: height
        )
        route_networks(scene)
        place_network_labels(scene)
        scene
      end

      private

      def measure_node(node)
        tag_width = Text.grid(Text.width(node.kind.to_s.upcase, 8, font: :mono) + 16)
        badge_text = "x#{node.replicas}" if node.replicas > 1
        badge_width = badge_text ? Text.grid(Text.width(badge_text, 8, font: :mono) + 12) : 0
        title_width = Text.width(node.label, 14) + 24
        artifact_width = node.artifacts.map do |item|
          Text.width(item.name, 12) + Text.width(item.version, 9, font: :mono) + 44
        end.max
        width = Text.grid([NODE_MIN_WIDTH, title_width, artifact_width, tag_width + badge_width + 36].max)
        height = 52 + node.artifacts.size * CHIP_HEIGHT + (node.artifacts.size - 1) * CHIP_GAP + 12
        chip_width = width - 24
        artifacts = node.artifacts.each_with_index.map do |item, index|
          top = 52 + index * (CHIP_HEIGHT + CHIP_GAP)
          {
            artifact: item,
            relative_rect: [12, top, 12 + chip_width, top + CHIP_HEIGHT]
          }
        end
        Box.new(
          node: node, width: width, height: height, lines: [node.label], details: [], shape: :deployment,
          artifacts: artifacts,
          type_tag: { text: node.kind.to_s.upcase, relative_rect: [12, 8, 12 + tag_width, 24] },
          replica_badge: badge_text && { text: badge_text, width: badge_width }
        )
      end

      def place_zones(boxes)
        cursor_x = MARGIN
        @d.zones.map do |zone|
          members = boxes.select { |box| box.node.zone == zone.id }
          label_width = Text.width(zone.label.upcase, 8, font: :mono) + 32
          zone_width = Text.grid([members.map(&:width).max + ZONE_PADDING * 2, label_width].max)
          cursor_y = ZONE_TOP + ZONE_HEADER
          members.each do |box|
            box.x = Text.grid(cursor_x + (zone_width - box.width) / 2.0)
            box.y = Text.grid(cursor_y)
            position_box_contents(box)
            cursor_y = box.bottom + NODE_GAP
          end
          bottom = members.last.bottom + ZONE_PADDING
          header_width = Text.grid(Text.width(zone.label.upcase, 8, font: :mono) + 16)
          item = {
            id: zone.id, label: zone.label, lines: [zone.label.upcase],
            rect: [cursor_x, ZONE_TOP, cursor_x + zone_width, bottom],
            header_rect: [cursor_x + 8, ZONE_TOP + 4, cursor_x + 8 + header_width, ZONE_TOP + 28]
          }
          cursor_x += zone_width + ZONE_GAP
          item
        end
      end

      def position_box_contents(box)
        box.type_tag[:rect] = translate(box, box.type_tag.delete(:relative_rect))
        if box.replica_badge
          badge_width = box.replica_badge[:width]
          box.replica_badge[:rect] = [box.right - 12 - badge_width, box.y + 8, box.right - 12, box.y + 24]
        end
        box.artifacts.each do |chip|
          chip[:rect] = translate(box, chip.delete(:relative_rect))
          item = chip[:artifact]
          chip[:name_x] = chip[:rect][0] + 8
          chip[:version_x] = chip[:rect][2] - 8
          name_right = chip[:name_x] + Text.width(item.name, 12)
          version_left = chip[:version_x] - Text.width(item.version, 9, font: :mono)
          if name_right + 12 > version_left
            raise LayoutError, "Artifact #{item.name.inspect} and version #{item.version.inspect} do not fit without overlap; shorten them"
          end
        end
      end

      def translate(box, rect)
        [box.x + rect[0], box.y + rect[1], box.x + rect[2], box.y + rect[3]]
      end

      def route_networks(scene)
        zone_order = @d.zones.each_with_index.to_h { |zone, index| [zone.id, index] }
        node_order = @d.zones.to_h do |zone|
          [zone.id, @d.nodes.select { |node| node.zone == zone.id }.each_with_index.to_h { |node, index| [node.id, index] }]
        end
        specs = @d.edges.each_with_index.map do |edge, index|
          source = scene.boxes.find { |box| box.node.id == edge.from }
          target = scene.boxes.find { |box| box.node.id == edge.to }
          source_side, target_side = attachment_sides(source.node, target.node, zone_order, node_order)
          { edge: edge, index: index, source: source, target: target,
            source_side: source_side, target_side: target_side }
        end
        assign_attachment_offsets(specs)
        headers = scene.zones.map { |zone| zone[:header_rect] }
        router = Router.new(scene.boxes, scene.width, scene.height, clearance: ROUTE_CLEARANCE, obstacles: headers)
        specs.sort_by { |spec| route_distance(spec) }.each do |spec|
          start = spec[:source].boundary(spec[:source_side], spec[:source_offset])
          finish = spec[:target].boundary(spec[:target_side], spec[:target_offset])
          start_stub = move(start, spec[:source_side], ROUTE_CLEARANCE)
          finish_stub = move(finish, spec[:target_side], ROUTE_CLEARANCE)
          begin
            middle = router.route(start_stub, finish_stub)
            points = Geometry.compact([start] + middle + [finish])
            router.commit(points)
          rescue LayoutError => error
            raise LayoutError, "Could not route deployment network #{spec[:edge].from} -> #{spec[:edge].to} (#{spec[:edge].label}): #{error.message}"
          end
          scene.routes << Route.new(edge: spec[:edge], points: points)
        end
        scene.routes.sort_by! { |route| @d.edges.index(route.edge) }
      end

      def attachment_sides(source, target, zone_order, node_order)
        if source.zone == target.zone
          if node_order.fetch(source.zone).fetch(source.id) < node_order.fetch(target.zone).fetch(target.id)
            %i[bottom top]
          else
            %i[top bottom]
          end
        elsif zone_order.fetch(source.zone) < zone_order.fetch(target.zone)
          %i[right left]
        else
          %i[left right]
        end
      end

      def assign_attachment_offsets(specs)
        endpoints = specs.flat_map do |spec|
          [[:source, spec[:source], spec[:source_side]], [:target, spec[:target], spec[:target_side]]].map do |role, box, side|
            { spec: spec, role: role, box: box, side: side }
          end
        end
        endpoints.group_by { |item| [item[:box].node.id, item[:side]] }.each_value do |items|
          span = %i[left right].include?(items.first[:side]) ? items.first[:box].height - 32 : items.first[:box].width - 40
          offsets = centered_offsets(items.size)
          if offsets.map(&:abs).max.to_i > span / 2 - 8
            node = items.first[:box].node.id
            raise LayoutError, "Too many deployment networks use the same side of #{node}; split the diagram"
          end
          items.sort_by { |item| item[:spec][:index] }.zip(offsets).each do |item, offset|
            item[:spec][:"#{item[:role]}_offset"] = offset
          end
        end
      end

      def centered_offsets(count)
        Array.new(count) { |index| ((index - (count - 1) / 2.0) * 16).round }
      end

      def route_distance(spec)
        (spec[:source].center[0] - spec[:target].center[0]).abs +
          (spec[:source].center[1] - spec[:target].center[1]).abs
      end

      def move(point, side, distance)
        case side
        when :top then [point[0], point[1] - distance]
        when :bottom then [point[0], point[1] + distance]
        when :left then [point[0] - distance, point[1]]
        when :right then [point[0] + distance, point[1]]
        end
      end

      def place_network_labels(scene)
        blockers = scene.boxes.map(&:rect) + scene.zones.map { |zone| zone[:header_rect] }
        labels = []
        scene.routes.each do |route|
          width = Text.grid(Text.width(route.edge.label, 8, font: :mono) + 16)
          candidates = label_candidates(route.points, width, 20)
          rect = candidates.find do |candidate|
            inside_scene?(candidate, scene) &&
              blockers.none? { |blocker| Geometry.overlaps?(candidate, expand(blocker, 4)) } &&
              labels.none? { |label| Geometry.overlaps?(candidate, expand(label[:rect], 8)) } &&
              own_route_clear?(candidate, route) && unrelated_routes_clear?(candidate, route, scene.routes)
          end
          unless rect
            raise LayoutError, "Could not place label #{route.edge.label.inspect} for deployment network #{route.edge.from} -> #{route.edge.to}; shorten labels or split the diagram"
          end
          route.label_box = { lines: [route.edge.label], rect: rect, network: true }
          labels << route.label_box
        end
      end

      def label_candidates(points, width, height)
        segments = points.each_cons(2).sort_by { |a, b| -((a[0] - b[0]).abs + (a[1] - b[1]).abs) }
        segments.flat_map do |a, b|
          cx, cy = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
          if a[1] == b[1]
            next [] if (a[0] - b[0]).abs < width + 16
            left = Text.grid(cx - width / 2.0)
            [[left, cy - 8 - height, left + width, cy - 8],
             [left, cy + 8, left + width, cy + 8 + height]]
          else
            next [] if (a[1] - b[1]).abs < height + 16
            [[a[0] + 8, Text.grid(cy - height / 2.0), a[0] + 8 + width, Text.grid(cy + height / 2.0)],
             [a[0] - 8 - width, Text.grid(cy - height / 2.0), a[0] - 8, Text.grid(cy + height / 2.0)]]
          end
        end
      end

      def own_route_clear?(rect, route)
        padded = expand(rect, 6)
        route.points.each_cons(2).none? { |a, b| Geometry.blocked?(a, b, padded) }
      end

      def unrelated_routes_clear?(rect, own_route, routes)
        padded = expand(rect, 8)
        routes.reject { |route| route.equal?(own_route) }.none? do |route|
          route.points.each_cons(2).any? { |a, b| Geometry.blocked?(a, b, padded) }
        end
      end

      def inside_scene?(rect, scene)
        rect[0] >= 8 && rect[1] >= 8 && rect[2] <= scene.width - 8 && rect[3] <= scene.height - 8
      end

      def expand(rect, amount)
        [rect[0] - amount, rect[1] - amount, rect[2] + amount, rect[3] + amount]
      end
    end
  end
end
