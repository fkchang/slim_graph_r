# frozen_string_literal: true
module SlimGraphR
  module Layout
    DPIntegrationScene = Struct.new(:width, :height, :zone, :bands, :components, :side_cards, :routes,
                                    :layer_services, :legend, keyword_init: true)

    class DPIntegration
      WIDTH = 1240
      SIDE_WIDTH = 160
      MAX_SIDE_WIDTH = 208
      SIDE_HEIGHT = 64
      SIDE_TOP = 92
      SIDE_STRIDE = 88
      LEFT_X = 40
      LEFT_CORRIDOR_WIDTH = 60
      RIGHT_CORRIDOR_WIDTH = 84
      PROTOCOL_LANE_STEP = 64
      ZONE_WIDTH = 696
      ZONE_Y = 72
      ZONE_PAD = 16
      ROW_HEIGHT = 72
      TALL_ROW_HEIGHT = 88
      MAX_ROW_HEIGHT = 120
      BAR_GAP = 16
      PORT_GAP = 12
      FOOTER_GAP = 52
      FOOTER_HEIGHT = 56

      def initialize(diagram) = @d = diagram

      def call
        surface = measured_surface
        side_count = [@d.integration_sources.size, @d.integration_consumers.size].max
        zone_height = [336, side_count * SIDE_STRIDE - 24].max
        zone = { x: surface[:zone_x], y: ZONE_Y, width: ZONE_WIDTH, height: zone_height, label: @d.integration_platform.label }
        measure_zone_label!(zone)
        bands, components = place_bands(zone)
        side_cards = place_side_cards(surface, zone)
        measure_cards!(side_cards, components)
        routes = place_routes(side_cards, components, surface, zone)
        ensure_routes_faithful!(routes, side_cards, components)
        layer_services = place_layer_services(zone, surface)
        ensure_layer_clearance!(layer_services, routes, side_cards + components)
        legend = place_legend(zone, layer_services, surface)
        footer_bottom = layer_services.empty? ? zone[:y] + zone[:height] : layer_services.last[:y] + FOOTER_HEIGHT
        height = [600, footer_bottom + 84].max
        DPIntegrationScene.new(width: surface[:width], height: height, zone: zone, bands: bands, components: components,
                               side_cards: side_cards, routes: routes, layer_services: layer_services, legend: legend)
      end

      private

      def measure_zone_label!(zone)
        label = zone[:label].upcase
        if tracked_width(label, 12, :mono, 1.44) > zone[:width] - 48
          raise LayoutError, "DP integration platform label #{zone[:label].inspect} does not fit its measured boundary; shorten it or split the diagram"
        end
        zone[:display_label] = label
        zone[:label_width] = Text.grid(tracked_width(label, 12, :mono, 1.44) + 20)
      end

      def place_bands(zone)
        definitions = @d.integration_platform.bands
        row_index = definitions.index { |band| band.kind == :row }
        row_height = measured_row_height(definitions.fetch(row_index))
        row_y = SIDE_TOP + SIDE_STRIDE - (row_height - SIDE_HEIGHT) / 2.0
        placements = Array.new(definitions.size)
        placements[row_index] = { band: definitions[row_index], x: zone[:x] + ZONE_PAD, y: row_y,
                                  width: zone[:width] - 2 * ZONE_PAD, height: row_height }

        cursor = row_y
        definitions[0...row_index].each_with_index.to_a.reverse_each do |band, index|
          height = bar_height(band)
          cursor -= BAR_GAP + height
          placements[index] = { band: band, x: zone[:x] + ZONE_PAD, y: cursor,
                                width: zone[:width] - 2 * ZONE_PAD, height: height }
        end

        after = definitions[(row_index + 1)..] || []
        cursor = zone[:y] + zone[:height] - 40
        after.each_with_index.to_a.reverse_each do |band, relative_index|
          height = bar_height(band)
          cursor -= height
          placements[row_index + 1 + relative_index] = { band: band, x: zone[:x] + ZONE_PAD, y: cursor,
                                                         width: zone[:width] - 2 * ZONE_PAD, height: height }
          cursor -= BAR_GAP
        end

        placements.each_cons(2) do |left, right|
          if left[:y] + left[:height] + BAR_GAP > right[:y]
            raise LayoutError, 'DP integration platform bands cannot keep 16px separation inside the fixed zone; remove a bar or split the diagram'
          end
        end
        if placements.any? { |entry| entry[:y] < zone[:y] + 24 || entry[:y] + entry[:height] > zone[:y] + zone[:height] - 24 }
          raise LayoutError, 'DP integration platform bands do not fit the fixed zone with boundary clearance; split the diagram'
        end

        components = []
        placements.each do |placement|
          band = placement[:band]
          if band.kind == :bar
            components << placement.merge(item: band.items.first, band_kind: :bar)
          else
            count = band.items.size
            widths = band.items.map { |item| measured_component_width(item) }
            gap = count == 1 ? 0 : (placement[:width] - widths.sum) / (count - 1)
            if gap < BAR_GAP
              raise LayoutError, 'DP integration row cards cannot keep measured content and 16px separation inside the platform zone; shorten labels or split the diagram'
            end
            band.items.each_with_index do |item, index|
              components << {
                item: item, band: band, band_kind: :row,
                x: placement[:x] + widths.take(index).sum + index * gap,
                y: placement[:y], width: widths.fetch(index), height: placement[:height]
              }
            end
          end
        end
        [placements, components]
      end

      def bar_height(band) = band.items.first.focal ? 56 : 44

      def measured_row_height(band)
        required = band.items.map do |item|
          source_lanes = @d.integration_wires.select do |wire|
            wire.to == item.id && @d.integration_sources.any? { |source| source.id == wire.from }
          end
          consumer_lanes = @d.integration_wires.select do |wire|
            wire.from == item.id && @d.integration_consumers.any? { |consumer| consumer.id == wire.to }
          end
          lanes = source_lanes.size >= consumer_lanes.size ? source_lanes : consumer_lanes
          [ROW_HEIGHT, (lanes.size - 1) * port_gap_for(lanes) + 24].max
        end.max || ROW_HEIGHT
        required = [required, TALL_ROW_HEIGHT].max if band.items.any? { |item| item.serves && item.detail }
        if required > MAX_ROW_HEIGHT
          raise LayoutError, "DP integration row needs #{required}px to keep measured endpoint lanes clear; split the diagram"
        end
        required
      end

      def measured_surface
        source_width = measured_side_width(@d.integration_sources, :source)
        consumer_width = measured_side_width(@d.integration_consumers, :consumer)
        source_routes = @d.integration_wires.count { |wire| @d.integration_sources.any? { |item| item.id == wire.from } }
        serve_routes = @d.integration_wires.count { |wire| @d.integration_consumers.any? { |item| item.id == wire.to } }
        source_corridor = LEFT_CORRIDOR_WIDTH + (source_width > SIDE_WIDTH ? [source_routes - 1, 0].max * PROTOCOL_LANE_STEP : 0)
        serve_corridor = RIGHT_CORRIDOR_WIDTH + (consumer_width > SIDE_WIDTH ? [serve_routes - 1, 0].max * PROTOCOL_LANE_STEP : 0)
        zone_x = LEFT_X + source_width + source_corridor
        consumer_x = zone_x + ZONE_WIDTH + serve_corridor
        { source_width: source_width, consumer_width: consumer_width, zone_x: zone_x,
          consumer_x: consumer_x, width: consumer_x + consumer_width + LEFT_X }
      end

      def measured_side_width(items, side)
        width = SIDE_WIDTH
        items.each do |item|
          required = [Text.width(item.detail.to_s, 12) + 48,
                      tracked_width(item.kind.to_s.tr('_', ' ').upcase, 8, :mono, 0.6) + 20].max
          width = [width, Text.grid(required)].max
          while width <= MAX_SIDE_WIDTH && Text.wrap(item.label, width - 48, 14).map(&:strip).size > 2
            width += 4
          end
          if width > MAX_SIDE_WIDTH
            raise LayoutError, "DP integration #{side} #{item.label.inspect} exceeds the bounded #{MAX_SIDE_WIDTH}px side-card layout; shorten it or split the diagram"
          end
        end
        width
      end

      def measured_component_width(item)
        required = [Text.width(item.detail.to_s, 12) + 28,
                    Text.width(item.label, 14) + 28].max
        width = [SIDE_WIDTH, Text.grid(required)].max
        if width > MAX_SIDE_WIDTH
          raise LayoutError, "DP integration component #{item.label.inspect} exceeds the bounded #{MAX_SIDE_WIDTH}px row-card layout; shorten it or split the diagram"
        end
        width
      end

      def place_side_cards(surface, zone)
        sources = @d.integration_sources.each_with_index.map do |item, index|
          { item: item, side: :source, x: LEFT_X, y: SIDE_TOP + index * SIDE_STRIDE,
            width: surface[:source_width], height: SIDE_HEIGHT }
        end
        consumers = @d.integration_consumers.each_with_index.map do |item, index|
          { item: item, side: :consumer, x: surface[:consumer_x], y: SIDE_TOP + index * SIDE_STRIDE,
            width: surface[:consumer_width], height: SIDE_HEIGHT }
        end
        sources + consumers
      end

      def measure_cards!(side_cards, components)
        side_cards.each do |entry|
          text_width = entry[:width] - 48
          entry[:title_lines] = Text.wrap(entry[:item].label, text_width, 14).map(&:strip)
          if entry[:title_lines].size > 2
            raise LayoutError, "DP integration #{entry[:side]} label #{entry[:item].label.inspect} does not fit its measured side card; shorten it or split the diagram"
          end
          if entry[:item].detail && Text.width(entry[:item].detail, 12) > text_width
            raise LayoutError, "DP integration #{entry[:side]} detail #{entry[:item].detail.inspect} does not fit its measured side card; shorten it"
          end
        end
        components.each do |entry|
          item = entry[:item]
          entry[:role_width] = item.role ? Text.grid(tracked_width(item.role.upcase, 12, :mono, 0.9) + 14) : 0
          badge_width = [entry[:role_width], item.serves ? 48 : 0].max
          label_budget = if entry[:band_kind] == :bar
            item.detail ? 146 : entry[:width] - badge_width - 48
          else
            entry[:width] - 28
          end
          entry[:title_lines] = Text.wrap(item.label, label_budget, 14).map(&:strip)
          raise LayoutError, "DP integration component label #{item.label.inspect} does not fit its measured card; shorten it or split the diagram" if entry[:title_lines].size > 2
          if item.role && tracked_width(item.role.upcase, 12, :mono, 0.9) > [entry[:width] - 24, 120].min
            raise LayoutError, "DP integration component role #{item.role.inspect} does not fit its measured badge; shorten it"
          end
          detail_budget = if entry[:band_kind] == :bar
            entry[:width] - 178 - badge_width - 28
          else
            entry[:width] - 28
          end
          if item.detail && Text.width(item.detail, 12) > detail_budget
            raise LayoutError, "DP integration component detail #{item.detail.inspect} does not fit its measured card; shorten it"
          end
        end
      end

      def place_routes(side_cards, components, surface, zone)
        boxes = (side_cards + components).to_h { |entry| [entry[:item].id, entry] }
        wire_sides = @d.integration_wires.to_h { |wire| [wire.object_id, sides_for(wire, boxes)] }
        ports = assign_ports(wire_sides, boxes)
        source_index = 0
        serve_index = 0
        routes = @d.integration_wires.map do |wire|
          start = ports.fetch([wire.object_id, wire.from])
          finish = ports.fetch([wire.object_id, wire.to])
          from = boxes.fetch(wire.from)
          to = boxes.fetch(wire.to)
          points = if from[:side] == :source
            corridor = from[:x] + from[:width] + 8 + source_index * PORT_GAP
            source_index += 1
            raise LayoutError, 'DP integration source routes cannot reserve distinct 12px corridors; split the diagram' if corridor >= zone[:x]
            [start, [corridor, start[1]], [corridor, finish[1]], finish]
          elsif to[:side] == :consumer
            corridor = to[:x] - 8 - serve_index * PORT_GAP
            serve_index += 1
            raise LayoutError, 'DP integration serving routes cannot reserve distinct 12px corridors; split the diagram' if corridor <= zone[:x] + zone[:width]
            [start, [corridor, start[1]], [corridor, finish[1]], finish]
          elsif wire.kind == :trigger
            start[0] == finish[0] ? [start, finish] : [start, [start[0], (start[1] + finish[1]) / 2.0],
                                                       [finish[0], (start[1] + finish[1]) / 2.0], finish]
          elsif start[1] == finish[1] || start[0] == finish[0]
            [start, finish]
          else
            [start, [finish[0], start[1]], finish]
          end
          points = Geometry.compact(points)
          {
            wire: wire, points: points, source_port: start, target_port: finish,
            label: nil
          }
        end
        place_protocol_labels!(routes, side_cards + components, surface[:width])
        routes
      end

      def sides_for(wire, boxes)
        from, to = boxes.fetch(wire.from), boxes.fetch(wire.to)
        return [:right, :left] if from[:side] == :source
        return [:right, :left] if to[:side] == :consumer
        if wire.kind == :trigger
          return from[:y] < to[:y] ? [:bottom, :top] : [:top, :bottom]
        end
        from_center = center(from)
        to_center = center(to)
        if (from_center[1] - to_center[1]).abs < 1
          from_center[0] < to_center[0] ? [:right, :left] : [:left, :right]
        else
          from_center[1] < to_center[1] ? [:bottom, :top] : [:top, :bottom]
        end
      end

      def assign_ports(wire_sides, boxes)
        grouped = Hash.new { |hash, key| hash[key] = [] }
        @d.integration_wires.each do |wire|
          from_side, to_side = wire_sides.fetch(wire.object_id)
          grouped[[wire.from, from_side]] << wire
          grouped[[wire.to, to_side]] << wire
        end
        grouped.each_with_object({}) do |((id, side), wires), result|
          box = boxes.fetch(id)
          if wires.all? { |wire| wire.kind == :trigger }
            positions = wires.map { |wire| center(boxes.fetch(wire.to))[0] }.sort
            if positions.each_cons(2).any? { |a, b| b - a < PORT_GAP }
              raise LayoutError, "DP integration endpoint #{id} cannot reserve distinct trigger ports 12px apart; split the diagram"
            end
            wires.each do |wire|
              x = center(boxes.fetch(wire.to))[0]
              result[[wire.object_id, id]] = side == :top ? [x, box[:y]] : [x, box[:y] + box[:height]]
            end
            next
          end
          gap = port_gap_for(wires)
          usable = %i[left right].include?(side) ? box[:height] - 24 : box[:width] - 24
          needed = (wires.size - 1) * gap
          if needed > usable
            raise LayoutError, "DP integration endpoint #{id} cannot reserve distinct ports 12px apart; split the diagram"
          end
          wires.each_with_index do |wire, index|
            offset = index * gap - needed / 2.0
            result[[wire.object_id, id]] = boundary(box, side, offset)
          end
        end
      end

      def protocol_candidates(wire, points, boxes)
        width = Text.grid(tracked_width(wire.protocol, 12, :mono, 1.05) + 12)
        if width > 104
          raise LayoutError, "DP integration protocol #{wire.protocol.inspect} is too long for a clear route label; shorten it or split the diagram"
        end
        points.each_cons(2).sort_by { |a, b| -((a[0] - b[0]).abs + (a[1] - b[1]).abs) }.flat_map do |left, right|
          if left[1] == right[1]
            next [] if (left[0] - right[0]).abs < width
            low, high = [left[0], right[0]].minmax
            [0.25, 0.5, 0.75].flat_map do |fraction|
              x = low + (high - low) * fraction - width / 2.0
              [left[1] - 23, left[1] + 9].map { |y| [x, y, x + width, y + 14] }
            end
          else
            top, bottom = [left[1], right[1]].minmax
            ys = [(top + bottom) / 2.0 - 7] + boxes.flat_map { |box| [box[:y] - 18, box[:y] + box[:height] + 4] }
            ys.select { |y| y >= top && y + 14 <= bottom }.uniq.flat_map do |y|
              [left[0] - 8 - width, left[0] + 8].map { |x| [x, y, x + width, y + 14] }
            end
          end
        end
      end

      def port_gap_for(wires)
        wires.size >= 3 && wires.any?(&:protocol) ? 32 : PORT_GAP
      end

      def place_protocol_labels!(routes, boxes, surface_width)
        placed = []
        routes.each do |route|
          wire = route[:wire]
          next unless wire.protocol
          rect = protocol_candidates(wire, route[:points], boxes).find do |candidate|
            candidate[0] >= 40 && candidate[2] <= surface_width - 40 &&
              boxes.none? { |box| Geometry.overlaps?(candidate, rect_for(box, 2)) } &&
              placed.none? { |label| Geometry.overlaps?(expand_rect(candidate, 4), label[:rect]) } &&
              routes.none? { |other| other[:points].each_cons(2).any? { |a, b| Geometry.blocked?(a, b, expand_rect(candidate, other == route ? 8 : 2)) } }
          end
          unless rect
            raise LayoutError, "DP integration protocol #{wire.protocol.inspect} cannot clear cards, labels and routes by its measured gap; shorten it or split the diagram"
          end
          route[:label] = { rect: rect, gap: 8, text: wire.protocol }
          placed << route[:label]
        end
      end

      def ensure_routes_faithful!(routes, side_cards, components)
        boxes = side_cards + components
        routes.each do |route|
          route[:points].each_cons(2) do |left, right|
            blocker = boxes.find do |box|
              padding = [route[:wire].from, route[:wire].to].include?(box[:item].id) ? 0 : 2
              Geometry.blocked?(left, right, rect_for(box, padding))
            end
            if blocker
              raise LayoutError, "DP integration route #{route[:wire].from} to #{route[:wire].to} is hidden by #{blocker[:item].id}; split the diagram or remove the conflicting wire"
            end
          end
          if route[:label]
            blocker = boxes.find { |box| Geometry.overlaps?(route[:label][:rect], rect_for(box)) }
            if blocker
              raise LayoutError, "DP integration protocol #{route[:wire].protocol.inspect} overlaps component #{blocker[:item].id}; shorten it or split the diagram"
            end
          end
        end
        routes.each_with_index do |route, index|
          routes[0...index].each do |previous|
            route[:points].each_cons(2) do |a, b|
              previous[:points].each_cons(2) do |c, d|
                if Geometry.parallel_conflict?(a, b, c, d, gap: PORT_GAP) || Geometry.crossing(a, b, c, d)
                  raise LayoutError, 'DP integration routes cross or cannot keep 12px separation; split the diagram'
                end
              end
            end
          end
        end
      end

      def place_layer_services(zone, surface)
        count = @d.integration_layer_services.size
        footer_width = surface[:width] - 80
        width = count.zero? ? footer_width : (footer_width - (count - 1) * 16) / count
        @d.integration_layer_services.each_with_index.map do |item, index|
          x = 40 + index * (width + 16)
          y = zone[:y] + zone[:height] + FOOTER_GAP
          target_x = [[x + width / 2.0, zone[:x] + 64].max, zone[:x] + zone[:width] - 32].min
          title_lines = Text.wrap(item.label, width - 72, 14).map(&:strip)
          raise LayoutError, "DP integration layer-service label #{item.label.inspect} does not fit its footer; shorten it" if title_lines.size > 1
          if item.detail && Text.width(item.detail, 12) > width - 72
            raise LayoutError, "DP integration layer-service detail #{item.detail.inspect} does not fit its footer; shorten it"
          end
          protocol_width = tracked_width(item.protocol, 12, :mono, 1.05)
          if protocol_width > 92
            raise LayoutError, "DP integration layer-service protocol #{item.protocol.inspect} is too long for its boundary route; shorten it or split the diagram"
          end
          label_width = Text.grid(protocol_width + 12)
          label_y = zone[:y] + zone[:height] + 11
          { item: item, x: x, y: y, width: width, height: FOOTER_HEIGHT, title_lines: title_lines,
            source: [target_x, y], target: [target_x, zone[:y] + zone[:height]], protocol_width: protocol_width,
            label: { rect: [target_x - 8 - label_width, label_y, target_x - 8, label_y + 14], gap: 8, text: item.protocol } }
        end
      end

      def ensure_layer_clearance!(layers, routes, boxes)
        labels = routes.filter_map { |route| route[:label] } + layers.map { |entry| entry[:label] }
        segments = routes.flat_map { |route| route[:points].each_cons(2).to_a } + layers.map { |entry| [entry[:source], entry[:target]] }
        layers.each do |entry|
          if boxes.any? { |box| Geometry.blocked?(entry[:source], entry[:target], rect_for(box, 2)) }
            raise LayoutError, "DP integration layer-service #{entry[:item].id} cannot reach the platform boundary clearly; split the diagram"
          end
        end
        labels.each_with_index do |label, index|
          if (boxes + layers).any? { |box| Geometry.overlaps?(label[:rect], rect_for(box, 2)) } ||
              labels[0...index].any? { |other| Geometry.overlaps?(expand_rect(label[:rect], 4), other[:rect]) } ||
              segments.any? { |a, b| Geometry.blocked?(a, b, expand_rect(label[:rect], 2)) }
            raise LayoutError, "DP integration protocol #{label[:text].inspect} cannot keep clear of the footer, cards, routes and other labels; shorten it or split the diagram"
          end
        end
      end

      def place_legend(zone, layer_services, surface)
        y = layer_services.empty? ? zone[:y] + zone[:height] + 36 : layer_services.last[:y] + FOOTER_HEIGHT + 28
        endpoint_kinds = (@d.integration_sources + @d.integration_consumers + @d.integration_layer_services).map(&:kind).uniq
        wire_kinds = @d.integration_wires.map(&:kind).uniq
        width = (endpoint_kinds + wire_kinds).sum { |kind| tracked_width(kind.to_s.upcase, 12, :mono, 1.2) + 40 }
        raise LayoutError, 'DP integration legend text does not fit the measured surface; split the diagram' if width > surface[:width] - 80
        { y: y, endpoint_kinds: endpoint_kinds, wire_kinds: wire_kinds }
      end

      def center(box) = [box[:x] + box[:width] / 2.0, box[:y] + box[:height] / 2.0]

      def boundary(box, side, offset)
        x, y = center(box)
        case side
        when :left then [box[:x], y + offset]
        when :right then [box[:x] + box[:width], y + offset]
        when :top then [x + offset, box[:y]]
        when :bottom then [x + offset, box[:y] + box[:height]]
        end
      end

      def rect_for(box, padding = 0)
        [box[:x] - padding, box[:y] - padding, box[:x] + box[:width] + padding, box[:y] + box[:height] + padding]
      end

      def expand_rect(rect, padding)
        [rect[0] - padding, rect[1] - padding, rect[2] + padding, rect[3] + padding]
      end

      def tracked_width(value, size, font, tracking)
        Text.width(value, size, font: font) + [value.length - 1, 0].max * tracking
      end
    end
  end
end
