# frozen_string_literal: true
module SlimGraphR
  module Layout
    class ItState
      MARGIN = 32
      PHASE_TOP = 24
      PHASE_HEADER = 40
      PHASE_PADDING = 16
      PHASE_GAP = 56
      SYSTEM_WIDTH = 240
      SYSTEM_GAP = 64
      ROUTE_CLEARANCE = 16
      FOOTER_GAP = 8
      FOOTER_MIN_HEIGHT = 56
      LEGEND_ROW_HEIGHT = 28

      def initialize(diagram) = @d = diagram

      def call
        boxes = @d.nodes.map { |node| measure_system(node) }
        zones, phase_bottom = place_phases(boxes)
        width = zones.last[:rect][2] + MARGIN
        footers, content_bottom = place_footers(width, phase_bottom)
        legend = legend_items
        legend_entries, legend_rect = place_legend(legend, width, content_bottom)
        scene = Scene.new(
          boxes: boxes, routes: [], zones: zones, lifelines: [], events: [], activations: [], fragments: [],
          callouts: [], footers: footers, legend: legend, legend_rect: legend_rect, legend_entries: legend_entries,
          width: width, height: legend_rect[3] + 24
        )
        route_handoffs(scene, phase_bottom + 16)
        scene
      end

      private

      def measure_system(node)
        lines = Text.wrap(node.label, SYSTEM_WIDTH - 40, 14)
        details = node.detail ? Text.wrap(node.detail, SYSTEM_WIDTH - 40, 12) : []
        content_height = lines.size * 20 + details.size * 16 + (details.empty? ? 0 : 6)
        height = Text.grid([64, content_height + 24].max)
        Box.new(
          node: node, width: SYSTEM_WIDTH, height: height, lines: lines, details: details,
          shape: :it_state
        )
      end

      def place_phases(boxes)
        stacks = @d.phases.to_h do |phase|
          members = boxes.select { |box| box.node.zone == phase.id }
          stack_height = members.sum(&:height) + [members.size - 1, 0].max * SYSTEM_GAP
          [phase.id, [members, stack_height]]
        end
        phase_height = PHASE_HEADER + PHASE_PADDING * 2 + stacks.values.map(&:last).max
        cursor_x = MARGIN
        zones = @d.phases.map do |phase|
          members, = stacks.fetch(phase.id)
          width = SYSTEM_WIDTH + PHASE_PADDING * 2
          cursor_y = PHASE_TOP + PHASE_HEADER
          members.each do |box|
            box.x = cursor_x + PHASE_PADDING
            box.y = cursor_y
            cursor_y = box.bottom + SYSTEM_GAP
          end
          header_width = Text.grid(Text.width(phase.label, 9, font: :mono) + 16)
          zone = {
            id: phase.id, label: phase.label, lines: [phase.label],
            rect: [cursor_x, PHASE_TOP, cursor_x + width, PHASE_TOP + phase_height],
            header_rect: [cursor_x + 12, PHASE_TOP - 8, cursor_x + 12 + header_width, PHASE_TOP + 10]
          }
          cursor_x += width + PHASE_GAP
          zone
        end
        [zones, PHASE_TOP + phase_height]
      end

      def place_footers(width, phase_bottom)
        cursor_y = phase_bottom + 24
        footers = @d.crosscuts.map do |item|
          label_lines = Text.wrap(item.label, width - MARGIN * 2 - 40, 14)
          detail_lines = item.detail ? Text.wrap(item.detail, width - MARGIN * 2 - 40, 12) : []
          content_height = label_lines.size * 20 + (detail_lines.empty? ? 0 : 4 + detail_lines.size * 16)
          height = Text.grid([FOOTER_MIN_HEIGHT, content_height + 24].max)
          label_y = cursor_y + 20
          footer = {
            crosscut: item, rect: [MARGIN, cursor_y, width - MARGIN, cursor_y + height],
            label_lines: label_lines, detail_lines: detail_lines, label_y: label_y,
            detail_y: label_y + label_lines.size * 20 + 2
          }
          cursor_y += height + FOOTER_GAP
          footer
        end
        bottom = footers.empty? ? phase_bottom : footers.last[:rect][3]
        [footers, bottom]
      end

      def legend_items
        styles = @d.edges.map { |item| @d.effective_handoff_style(item) }.uniq
        styles += [:dashed] if @d.edges.any?(&:dashed)
        styles += [:pain_point] if @d.nodes.any? { |node| node.kind == :pain_point }
        styles += [:external] if @d.nodes.any? { |node| node.kind == :external }
        %i[neutral link accent dashed pain_point external].select { |item| styles.include?(item) }
      end

      def place_legend(legend, width, content_bottom)
        labels = {
          neutral: 'Standard hand-off', link: 'Linked hand-off', accent: 'Pain-point hand-off',
          dashed: 'Dashed hand-off', pain_point: 'Pain point', external: 'External system'
        }
        top = content_bottom + 16
        x, y = MARGIN, top + 16
        entries = legend.map do |item|
          label = labels.fetch(item)
          item_width = Text.grid(Text.width(label, 10) + 36)
          if x > MARGIN && x + item_width > width - MARGIN
            x = MARGIN
            y += LEGEND_ROW_HEIGHT
          end
          entry = { kind: item, label: label, rect: [x, y, x + item_width, y + 20] }
          x += item_width
          entry
        end
        bottom = entries.empty? ? top + 24 : entries.last[:rect][3] + 8
        [entries, [MARGIN, top, width - MARGIN, bottom]]
      end

      def route_handoffs(scene, route_height)
        specs = route_specs(scene)
        assign_attachment_offsets(specs)
        labels = specs.map { |spec| source_label(spec) }
        validate_labels!(labels, scene)
        header_obstacles = scene.zones.map { |zone| expand(zone[:header_rect], 4) }
        label_obstacles = labels.map { |label| expand(label[:rect], 4) }
        router = Router.new(
          scene.boxes, scene.width, route_height, clearance: ROUTE_CLEARANCE,
          obstacles: header_obstacles + label_obstacles
        )
        specs.sort_by { |spec| -route_distance(spec) }.each do |spec|
          start = spec[:source].boundary(spec[:source_side], spec[:source_offset])
          finish = spec[:target].boundary(spec[:target_side], spec[:target_offset])
          start_stub = move(start, spec[:source_side], source_stub_length(spec))
          finish_stub = move(finish, spec[:target_side], ROUTE_CLEARANCE)
          begin
            middle = router.route(start_stub, finish_stub)
            points = Geometry.compact([start] + middle + [finish])
            router.commit(points)
          rescue LayoutError => error
            raise LayoutError, "Could not route IT current-state hand-off #{spec[:edge].from} -> #{spec[:edge].to} (#{spec[:edge].label}): #{error.message}"
          end
          label = labels.fetch(spec[:index])
          label[:style] = @d.effective_handoff_style(spec[:edge])
          scene.routes << Route.new(edge: spec[:edge], points: points, label_box: label)
        end
        scene.routes.sort_by! { |route| @d.edges.index(route.edge) }
        validate_route_clearance!(scene)
      end

      def route_specs(scene)
        phase_order = @d.phases.each_with_index.to_h { |phase, index| [phase.id, index] }
        system_order = @d.phases.to_h do |phase|
          members = @d.nodes.select { |node| node.zone == phase.id }
          [phase.id, members.each_with_index.to_h { |node, index| [node.id, index] }]
        end
        @d.edges.each_with_index.map do |edge, index|
          source = scene.boxes.find { |box| box.node.id == edge.from }
          target = scene.boxes.find { |box| box.node.id == edge.to }
          source_side, target_side = attachment_sides(source.node, target.node, phase_order, system_order)
          { edge: edge, index: index, source: source, target: target, source_side: source_side, target_side: target_side }
        end
      end

      def attachment_sides(source, target, phase_order, system_order)
        if source.zone == target.zone
          source_index = system_order.fetch(source.zone).fetch(source.id)
          target_index = system_order.fetch(target.zone).fetch(target.id)
          source_index < target_index ? %i[bottom top] : %i[top bottom]
        elsif phase_order.fetch(source.zone) < phase_order.fetch(target.zone)
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
          box, side = items.first.values_at(:box, :side)
          span = %i[left right].include?(side) ? box.height - 24 : box.width - 40
          offsets = centered_offsets(items.size)
          if offsets.map(&:abs).max.to_i > span / 2
            raise LayoutError, "Too many IT current-state hand-offs use the same side of #{box.node.id}; split the landscape"
          end
          items.sort_by { |item| item[:spec][:index] }.zip(offsets).each do |item, offset|
            item[:spec][:"#{item[:role]}_offset"] = offset
          end
        end
      end

      def centered_offsets(count)
        Array.new(count) { |index| ((index - (count - 1) / 2.0) * 16).round }
      end

      def source_label(spec)
        edge = spec[:edge]
        width = Text.grid(Text.width(edge.label, 9, font: :mono) + 12)
        start = spec[:source].boundary(spec[:source_side], spec[:source_offset])
        x, y = start
        rect = case spec[:source_side]
        when :right then [x + 6, y - 23, x + 6 + width, y - 5]
        when :left then [x - 6 - width, y - 23, x - 6, y - 5]
        when :bottom then [x + 6, y + 5, x + 6 + width, y + 23]
        when :top then [x + 6, y - 23, x + 6 + width, y - 5]
        end
        { lines: [edge.label], rect: rect, handoff: true, source_side: spec[:source_side] }
      end

      def validate_labels!(labels, scene)
        blockers = scene.boxes.map(&:rect) + scene.zones.map { |zone| zone[:header_rect] } +
          scene.footers.map { |footer| footer[:rect] } + [scene.legend_rect]
        labels.each_with_index do |label, index|
          if blockers.any? { |blocker| Geometry.overlaps?(label[:rect], blocker) }
            edge = @d.edges.fetch(index)
            raise LayoutError, "Could not place source label #{edge.label.inspect} for IT current-state hand-off #{edge.from} -> #{edge.to}; split the landscape"
          end
          if labels.first(index).any? { |other| Geometry.overlaps?(expand(label[:rect], 4), expand(other[:rect], 4)) }
            edge = @d.edges.fetch(index)
            raise LayoutError, "Source labels crowd IT current-state system #{edge.from}; split the landscape"
          end
        end
      end

      def validate_route_clearance!(scene)
        blockers = scene.zones.map { |zone| zone[:header_rect] } + scene.footers.map { |footer| footer[:rect] } + [scene.legend_rect]
        scene.routes.each do |route|
          route.points.each_cons(2) do |from, to|
            if blockers.any? { |rect| Geometry.blocked?(from, to, rect) }
              raise LayoutError, "IT current-state hand-off #{route.edge.from} -> #{route.edge.to} enters reserved header, footer, or legend geometry"
            end
          end
        end
      end

      def source_stub_length(spec)
        width = spec[:source_side] == :left || spec[:source_side] == :right ?
          spec[:source].width : spec[:source].height
        label_width = spec[:source_side] == :left || spec[:source_side] == :right ?
          Text.grid(Text.width(spec[:edge].label, 9, font: :mono) + 12) : 18
        [[label_width + 20, ROUTE_CLEARANCE * 2].max, width].min
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

      def expand(rect, amount)
        [rect[0] - amount, rect[1] - amount, rect[2] + amount, rect[3] + amount]
      end
    end
  end
end
