# frozen_string_literal: true
module SlimGraphR
  module Layout
    class HighLevel
      WIDTH = 1000
      RIGHT_STRIP_WIDTH = 28
      STRIP_MARGIN = 8
      BANNER_TOP = 4
      BANNER_HEIGHT = 28
      BODY_TOP = 40
      BODY_BOTTOM = 376
      NODE_WIDTH = 152
      NODE_HEIGHT = 80
      SOURCE_HEIGHT = 64
      STACK_GAP = 16
      CROSSCUT_TOP = 388
      CROSSCUT_HEIGHT = 40
      CROSSCUT_GAP = 4

      def initialize(diagram) = @d = diagram

      def call
        effective_width = cross_spanning? ? WIDTH - RIGHT_STRIP_WIDTH - STRIP_MARGIN : WIDTH
        banners = place_banners(effective_width)
        source_zone = source_zone(banners.first)
        cluster = cluster(banners.first, effective_width)
        orchestration = place_orchestration(cluster)
        boxes = place_boxes(banners, source_zone, orchestration)
        footers = place_crosscuts(effective_width)
        strip_bottom = [428, CROSSCUT_TOP + footers.size * (CROSSCUT_HEIGHT + CROSSCUT_GAP) - CROSSCUT_GAP].max
        verticals = place_verticals(strip_bottom)
        routes = place_routes(boxes, banners, cluster, orchestration)
        legend = %i[primary secondary trigger].select { |style| routes.any? { |route| route.style == style } }
        legend_entries, legend_rect = place_legend(legend, effective_width, strip_bottom)
        height = [540, strip_bottom + 112].max
        validate_scene!(boxes, routes, banners, source_zone, cluster, orchestration, footers, verticals, legend_rect, height)
        Scene.new(
          boxes: boxes, routes: routes, zones: [], width: WIDTH, height: height, lifelines: [], events: [],
          activations: [], fragments: [], callouts: [], footers: footers, legend: legend,
          legend_rect: legend_rect, legend_entries: legend_entries, banners: banners,
          source_zone: source_zone, cluster: cluster, orchestration: orchestration,
          verticals: verticals, effective_width: effective_width
        )
      end

      private

      def cross_spanning? = @d.orchestration || !@d.crosscuts.empty?

      def place_banners(effective_width)
        unit = (effective_width / @d.phases.sum(&:columns) / 4).floor * 4
        widths = @d.phases.map { |phase| unit * phase.columns }
        widths[-1] += effective_width - widths.sum
        cursor = 0
        @d.phases.each_with_index.map do |phase, index|
          width = widths.fetch(index)
          rect = [cursor, BANNER_TOP, cursor + width, BANNER_TOP + BANNER_HEIGHT]
          rendered_label = phase.label.upcase.freeze
          ensure_text_fits!(rendered_label, width - 24, 12, :mono, "phase label #{phase.label.inspect}", letter_spacing: 1.68)
          item = {
            phase: phase, label: rendered_label, rect: rect, cx: cursor + width / 2,
            points: horizontal_chevron_points(rect, index, @d.phases.size)
          }
          cursor += width
          item
        end
      end

      def horizontal_chevron_points(rect, index, count)
        left, top, right, bottom = rect
        middle = top + BANNER_HEIGHT / 2
        return [[left, top], [right - 12, top], [right, middle], [right - 12, bottom], [left, bottom]] if index.zero?
        return [[left, top], [right, top], [right, bottom], [left, bottom], [left + 12, middle]] if index == count - 1
        [[left, top], [right - 12, top], [right, middle], [right - 12, bottom], [left, bottom], [left + 12, middle]]
      end

      def source_zone(first_banner)
        { rect: [4, BODY_TOP, first_banner[:rect][2] - 4, BODY_BOTTOM] }
      end

      def cluster(first_banner, effective_width)
        left = first_banner[:rect][2] + 4
        ensure_text_fits!(@d.cluster, effective_width - left - 32, 12, :sans, 'cluster label')
        { label: @d.cluster, rect: [left, BODY_TOP, effective_width, BODY_BOTTOM] }
      end

      def place_orchestration(cluster)
        return unless @d.orchestration
        left = cluster[:rect][0] + 12
        right = cluster[:rect][2] - 12
        ensure_text_fits!(@d.orchestration.label, right - left - 40, 14, :sans, 'orchestration label')
        ensure_text_fits!(@d.orchestration.detail, right - left - 40, 12, :mono, 'orchestration detail') if @d.orchestration.detail
        { owner: @d.orchestration, rect: [left, 52, right, 96] }
      end

      def place_boxes(banners, source_zone, orchestration)
        by_phase = banners.to_h { |item| [item[:phase].id, item] }
        source_width = source_zone[:rect][2] - source_zone[:rect][0] - 8
        sources = @d.sources.each_with_index.map do |source, index|
          ensure_text_fits!(source.label, source_width - 24, 14, :sans, "source label #{source.label.inspect}")
          ensure_text_fits!(source.detail, source_width - 24, 12, :mono, "source detail #{source.detail.inspect}") if source.detail
          Box.new(
            node: source, x: source_zone[:rect][0] + 4, y: 60 + index * (SOURCE_HEIGHT + STACK_GAP),
            width: source_width, height: SOURCE_HEIGHT, lines: [source.label], details: source.detail ? [source.detail] : [],
            shape: :high_level_source
          )
        end
        components = @d.components.map do |component|
          members = @d.components.select { |item| item.phase == component.phase }
          index = members.index(component)
          banner = by_phase.fetch(component.phase)
          ensure_text_fits!(component.label, NODE_WIDTH - 24, 14, :sans, "component label #{component.label.inspect}")
          ensure_text_fits!(component.detail, NODE_WIDTH - 24, 12, :mono, "component detail #{component.detail.inspect}") if component.detail
          Box.new(
            node: component, x: banner[:cx] - NODE_WIDTH / 2,
            y: (orchestration ? 120 : 64) + index * (NODE_HEIGHT + STACK_GAP),
            width: NODE_WIDTH, height: NODE_HEIGHT, lines: [component.label],
            details: component.detail ? [component.detail] : [], shape: :high_level_component
          )
        end
        sources + components
      end

      def place_crosscuts(effective_width)
        @d.crosscuts.each_with_index.map do |item, index|
          top = CROSSCUT_TOP + index * (CROSSCUT_HEIGHT + CROSSCUT_GAP)
          ensure_text_fits!(item.label, effective_width - 80, 14, :sans, "crosscut label #{item.label.inspect}")
          ensure_text_fits!(item.detail, effective_width - 80, 12, :mono, "crosscut detail #{item.detail.inspect}") if item.detail
          { crosscut: item, rect: [4, top, effective_width, top + CROSSCUT_HEIGHT] }
        end
      end

      def place_verticals(strip_bottom)
        pairs = []
        pairs << { concern: @d.orchestration.concern, kind: :orchestration, owner: @d.orchestration } if @d.orchestration
        pairs.concat(@d.crosscuts.map { |item| { concern: item.concern, kind: :crosscut, owner: item } })
        return [] if pairs.empty?
        total = strip_bottom - BODY_TOP
        base = (total / pairs.size / 4).floor * 4
        heights = Array.new(pairs.size, base)
        heights[-1] += total - heights.sum
        cursor = BODY_TOP
        pairs.each_with_index.map do |pair, index|
          rect = [WIDTH - RIGHT_STRIP_WIDTH, cursor, WIDTH, cursor + heights.fetch(index)]
          rendered_label = pair[:concern].upcase.freeze
          ensure_text_fits!(rendered_label, heights.fetch(index) - 24, 12, :mono, "vertical concern #{pair[:concern].inspect}", letter_spacing: 1.68)
          item = pair.merge(label: rendered_label, rect: rect, points: vertical_chevron_points(rect, index, pairs.size))
          cursor = rect[3]
          item
        end
      end

      def vertical_chevron_points(rect, index, count)
        left, top, right, bottom = rect
        center = left + RIGHT_STRIP_WIDTH / 2
        return [[left, top], [right, top], [right, bottom - 12], [center, bottom], [left, bottom - 12]] if index.zero?
        return [[left, top], [center, top + 12], [right, top], [right, bottom], [left, bottom]] if index == count - 1
        [[left, top], [center, top + 12], [right, top], [right, bottom - 12], [center, bottom], [left, bottom - 12]]
      end

      def place_routes(boxes, banners, cluster, orchestration)
        routes = data_routes(boxes, banners, cluster)
        if orchestration
          @d.orchestration.targets.each do |target_id|
            target = box_for(boxes, target_id)
            points = [[target.center[0], orchestration[:rect][3]], [target.center[0], target.y]]
            edge = HighLevelConnection.new(from: @d.orchestration.id, to: target_id).freeze
            routes << Route.new(edge: edge, points: points, style: :trigger)
          end
        end
        validate_routes!(routes, boxes)
        routes
      end

      def data_routes(boxes, banners, cluster)
        phase_banners = banners.to_h { |item| [item[:phase].id, item] }
        outgoing = @d.connections.group_by(&:from)
        incoming = @d.connections.group_by(&:to)
        source_offsets = attachment_offsets(outgoing)
        target_offsets = attachment_offsets(incoming)
        focal = @d.components.find(&:focal)
        @d.connections.map do |edge|
          source = box_for(boxes, edge.from)
          target = box_for(boxes, edge.to)
          start = [source.right, source.center[1] + source_offsets.fetch(edge)]
          finish = [target.x, target.center[1] + target_offsets.fetch(edge)]
          points = if start[1] == finish[1]
            [start, finish]
          else
            trunk = trunk_x(edge, source, target, phase_banners, cluster, outgoing.fetch(edge.from))
            Geometry.compact([start, [trunk, start[1]], [trunk, finish[1]], finish])
          end
          style = [edge.from, edge.to].include?(focal.id) ? :primary : :secondary
          Route.new(edge: edge, points: points, style: style)
        end
      end

      def attachment_offsets(groups)
        groups.each_value.each_with_object({}) do |edges, result|
          offsets = centered_offsets(edges.size)
          edges.each_with_index { |edge, index| result[edge] = offsets.fetch(index) }
        end
      end

      def centered_offsets(count) = Array.new(count) { |index| ((index - (count - 1) / 2.0) * 16).round }

      def trunk_x(edge, source, target, phase_banners, cluster, siblings)
        return cluster[:rect][0] - 8 if source.node.is_a?(HighLevelSource)
        boundary = phase_banners.fetch(source.node.phase)[:rect][2]
        rank = siblings.index(edge)
        trunk = siblings.size == 1 ? boundary + 4 : boundary - 8 + rank * 12
        if trunk <= source.right || target.x - trunk < 16
          raise LayoutError, "Could not route high-level connection #{edge.from} -> #{edge.to} with a visible arrow body; split the fan-out"
        end
        trunk
      end

      def validate_routes!(routes, boxes)
        routes.each do |route|
          if route.points.size - 2 > 2
            raise LayoutError, "High-level connection #{route.edge.from} -> #{route.edge.to} needs more than two bends"
          end
          final_length = manhattan(route.points[-2], route.points[-1])
          if final_length < 16
            raise LayoutError, "High-level connection #{route.edge.from} -> #{route.edge.to} has no room for a visible arrow body; split the diagram"
          end
          boxes.reject { |box| [route.edge.from, route.edge.to].include?(box.node.id) }.each do |box|
            if route.points.each_cons(2).any? { |from, to| Geometry.blocked?(from, to, box.rect) }
              raise LayoutError, "High-level connection #{route.edge.from} -> #{route.edge.to} crosses component #{box.node.id}; split the diagram"
            end
          end
        end
        routes.each_with_index do |route, index|
          routes.first(index).each do |other|
            next unless route.points.each_cons(2).any? do |a, b|
              other.points.each_cons(2).any? { |c, d| Geometry.parallel_conflict?(a, b, c, d) }
            end
            related = route.edge.from == other.edge.from || route.edge.to == other.edge.to
            next if related && route.style == other.style
            raise LayoutError, "Unrelated high-level connections #{other.edge.from} -> #{other.edge.to} and #{route.edge.from} -> #{route.edge.to} crowd one corridor; split the diagram"
          end
        end
      end

      def place_legend(legend, effective_width, strip_bottom)
        labels = { primary: 'Focal data path', secondary: 'Data path', trigger: 'Orchestration trigger' }
        cursor = 40
        top = strip_bottom + 24
        entries = legend.map do |kind|
          width = Text.grid(Text.width(labels.fetch(kind), 12, font: :mono) + 48)
          entry = { kind: kind, label: labels.fetch(kind), rect: [cursor, top, cursor + width, top + 24] }
          cursor += width + 12
          entry
        end
        raise LayoutError, 'High-level legend does not fit the body width' if cursor > effective_width - 28
        [entries, [40, top, effective_width - 40, top + 48]]
      end

      def validate_scene!(boxes, routes, banners, source_zone, cluster, orchestration, footers, verticals, legend_rect, height)
        boxes.each do |box|
          banner = banners.find { |item| item[:phase].id == box.node.phase }
          raise LayoutError, "High-level component #{box.node.id} is not centered under its phase" unless box.center[0] == banner[:cx]
          container = box.node.is_a?(HighLevelSource) ? source_zone[:rect] : cluster[:rect]
          unless contains?(container, box.rect)
            raise LayoutError, "High-level #{box.node.id} does not fit inside its #{box.node.is_a?(HighLevelSource) ? 'source zone' : 'cluster'}"
          end
        end
        raise LayoutError, 'High-level source zone overlaps the cluster boundary' if Geometry.overlaps?(source_zone[:rect], cluster[:rect])
        if orchestration && !contains?(cluster[:rect], orchestration[:rect])
          raise LayoutError, 'High-level orchestration bar does not fit inside the cluster'
        end
        footers.each { |footer| raise LayoutError, 'High-level crosscut does not fit the body width' unless footer[:rect][2] <= verticals.first[:rect][0] - STRIP_MARGIN }
        raise LayoutError, 'High-level legend exceeds the canvas' unless legend_rect[3] <= height
        routes
      end

      def contains?(outer, inner)
        outer[0] <= inner[0] && outer[1] <= inner[1] && outer[2] >= inner[2] && outer[3] >= inner[3]
      end

      def box_for(boxes, id) = boxes.find { |box| box.node.id == id }
      def manhattan(left, right) = (left[0] - right[0]).abs + (left[1] - right[1]).abs

      def ensure_text_fits!(value, width, size, font, subject, letter_spacing: 0)
        return if Text.width(value, size, font: font) + value.length * letter_spacing <= width
        raise LayoutError, "High-level #{subject} does not fit its fixed box; shorten it"
      end
    end
  end
end
