# frozen_string_literal: true
module SlimGraphR
  module Layout
    DataFlowScene = Struct.new(:width, :height, :role_column, :roles, :steps, :cards, :routes, :legend, keyword_init: true)

    class DataFlow
      STEP_SLOT = 168
      STEP_HEADER = 36
      ROLE_BAND = 116
      CARD_WIDTH = 152
      DETAIL_CARD_WIDTH = 164
      CARD_HEIGHT = 72
      CARD_INSET = 8
      OUTER_LEFT = 20
      OUTER_RIGHT = 40
      PORT_GAP = 12
      CHIP_TEXT_SIZE = 12
      DETAIL_TEXT_SIZE = 12
      CHIP_HORIZONTAL_PADDING = 12
      CHIP_HEIGHT = 16

      def self.chip_width(value)
        Text.grid(Text.width(value.to_s.upcase, CHIP_TEXT_SIZE, font: :mono) + CHIP_HORIZONTAL_PADDING)
      end

      def self.payload_legend_entry_width(payload)
        Text.width(payload.to_s.upcase, CHIP_TEXT_SIZE, font: :mono) + 34
      end

      def self.handoff_legend_entry_width(kind)
        Text.width(kind.to_s.upcase, CHIP_TEXT_SIZE, font: :mono) + 52
      end

      def initialize(diagram) = @d = diagram

      def call
        role_column = measured_role_column
        card_widths = measured_card_widths
        step_slots = measured_step_slots(card_widths)
        width = OUTER_LEFT + role_column + step_slots.sum + OUTER_RIGHT
        steps = place_steps(role_column, step_slots)
        roles = place_roles(role_column)
        cards = place_cards(steps, card_widths)
        ports = assign_ports(cards)
        routes = place_routes(cards, ports)
        ensure_route_separation!(routes)
        legend = place_legend(width)
        height = STEP_HEADER + @d.data_flow_roles.size * ROLE_BAND + legend[:height] + 24
        DataFlowScene.new(
          width: width, height: height, role_column: role_column, roles: roles, steps: steps,
          cards: cards, routes: routes, legend: legend
        )
      end

      private

      def measured_role_column
        widest = @d.data_flow_roles.map do |item|
          tracked_width(item.label.upcase, 12, :sans, 1.44)
        end.max
        if widest > 176
          raise LayoutError, 'A data-flow role label does not fit the measured role column; shorten it or split the diagram'
        end
        Text.grid([120, widest + 24].max)
      end

      def place_steps(role_column, step_slots)
        x = OUTER_LEFT + role_column
        @d.data_flow_steps.each_with_index.map do |item, index|
          label = item.label.upcase
          if tracked_width(label, 12, :mono, 1.44) > CARD_WIDTH - 12
            raise LayoutError, "Data-flow step label #{item.label.inspect} does not fit its measured header; shorten it or split the diagram"
          end
          width = step_slots.fetch(index)
          entry = { step: item, x: x, width: width, label: label }
          x += width
          entry
        end
      end

      def place_roles(role_column)
        @d.data_flow_roles.each_with_index.map do |item, index|
          { role: item, x: OUTER_LEFT, y: STEP_HEADER + index * ROLE_BAND, width: role_column, height: ROLE_BAND }
        end
      end

      def measured_card_widths
        @d.data_flow_transfers.to_h do |item|
          width = if item.detail
            measured = Text.grid(Text.width(item.detail, DETAIL_TEXT_SIZE, font: :mono) + 16)
            [DETAIL_CARD_WIDTH, measured].max
          else
            CARD_WIDTH
          end
          [item.id, width]
        end
      end

      def measured_step_slots(card_widths)
        @d.data_flow_steps.map do |step|
          widths = @d.data_flow_transfers.select { |item| item.step == step.id }.map { |item| card_widths.fetch(item.id) }
          [STEP_SLOT, widths.max.to_i + 2 * CARD_INSET].max
        end
      end

      def place_cards(steps, card_widths)
        role_order = @d.data_flow_roles.each_with_index.to_h { |item, index| [item.id, index] }
        step_positions = steps.to_h { |entry| [entry[:step].id, entry] }
        @d.data_flow_transfers.map do |item|
          card_width = card_widths.fetch(item.id)
          lines = Text.wrap(item.label, 100, 14).map(&:strip)
          if lines.size > 2 || (item.detail && Text.wrap(item.label, card_width - 16, 12).size > 1)
            raise LayoutError, "Data-flow transfer title #{item.label.inspect} does not fit the measured #{card_width}px card; shorten it"
          end
          if Text.width(item.tool, 12) > card_width - 16
            raise LayoutError, "Data-flow transfer tool #{item.tool.inspect} does not fit the measured #{card_width}px card; shorten it"
          end
          step = step_positions.fetch(item.step)
          {
            transfer: item,
            x: step[:x] + (step[:width] - card_width) / 2.0,
            y: STEP_HEADER + role_order.fetch(item.role) * ROLE_BAND + CARD_INSET,
            width: card_width, height: item.detail ? CARD_HEIGHT + 28 : CARD_HEIGHT,
            title_lines: item.detail ? Text.wrap(item.label, card_width - 16, 12).map(&:strip) : lines
          }
        end
      end

      def assign_ports(cards)
        endpoint_sides = Hash.new { |hash, key| hash[key] = [] }
        @d.data_flow_handoffs.each do |item|
          source = card_for(cards, item.from)
          target = card_for(cards, item.to)
          if item.kind == :trigger
            endpoint_sides[[item.from, :bottom]] << item
            endpoint_sides[[item.to, :top]] << item
          elsif item.kind == :focal
            downward = source[:y] < target[:y]
            endpoint_sides[[item.from, downward ? :bottom : :top]] << item
            endpoint_sides[[item.to, downward ? :top : :bottom]] << item
          else
            endpoint_sides[[item.from, :right]] << item
            endpoint_sides[[item.to, :left]] << item
          end
        end
        endpoint_sides.each_with_object({}) do |((transfer_id, side), items), result|
          card = card_for(cards, transfer_id)
          usable = %i[left right].include?(side) ? CARD_HEIGHT - 24 : card[:width] - 24
          needed = (items.size - 1) * PORT_GAP
          if needed > usable
            raise LayoutError, "Data-flow transfer #{transfer_id} cannot reserve distinct ports 12px apart; split the diagram"
          end
          items.each_with_index do |item, index|
            offset = index * PORT_GAP - needed / 2.0
            result[[item.object_id, transfer_id]] = boundary(card, side, offset)
          end
        end
      end

      def place_routes(cards, ports)
        @d.data_flow_handoffs.map do |item|
          source = card_for(cards, item.from)
          target = card_for(cards, item.to)
          start = ports.fetch([item.object_id, item.from])
          finish = ports.fetch([item.object_id, item.to])
          points = if item.kind == :trigger
            unless start[0] == finish[0]
              raise LayoutError, 'Data-flow direct-vertical trigger ports cannot align without a diagonal; split the diagram'
            end
            [start, finish]
          elsif item.kind == :focal
            direction = finish[1] > start[1] ? 1 : -1
            corridor_y = start[1] + direction * CARD_INSET
            [start, [start[0], corridor_y], [finish[0], corridor_y], finish]
          else
            arrival_x = arrival_x_for(item, target)
            [start, [arrival_x, start[1]], [arrival_x, finish[1]], finish]
          end
          points = Geometry.compact(points)
          ensure_unblocked!(item, points, cards)
          label = item.kind == :focal ? focal_label(item, points) : nil
          { handoff: item, points: points, pieces: route_pieces(points, label), source_port: start, target_port: finish, label: label }
        end
      end

      def arrival_x_for(item, target)
        incoming = @d.data_flow_handoffs.select do |candidate|
          candidate.to == item.to && %i[ordinary publish].include?(candidate.kind)
        end
        if incoming.size > 2
          raise LayoutError, "Data-flow transfer #{item.to} cannot reserve distinct arrival routes 12px apart; split the diagram"
        end
        index = incoming.index(item)
        target[:x] - CARD_INSET + (index - (incoming.size - 1) / 2.0) * PORT_GAP
      end

      def ensure_unblocked!(item, points, cards)
        unrelated = cards.reject { |card| [item.from, item.to].include?(card[:transfer].id) }
        points.each_cons(2) do |a, b|
          blocker = unrelated.find { |card| Geometry.blocked?(a, b, card_rect(card, 2)) }
          next unless blocker
          qualifier = item.kind == :focal ? 'focal arrival' : "#{item.kind} route"
          raise LayoutError, "Data-flow #{qualifier} is blocked by transfer #{blocker[:transfer].id}; split the diagram or remove the conflicting route"
        end
      end

      def focal_label(item, points)
        horizontal = points.each_cons(2).find { |a, b| a[1] == b[1] && (a[0] - b[0]).abs > 0 }
        raise LayoutError, 'Data-flow focal route has no horizontal corridor for its label; split the diagram' unless horizontal
        a, b = horizontal
        width = Text.grid(Text.width(item.label, 12, font: :mono) + 12)
        if (a[0] - b[0]).abs < width + 16
          raise LayoutError, "Data-flow focal label #{item.label.inspect} cannot keep an 8px path gap; shorten it or split the diagram"
        end
        center = (a[0] + b[0]) / 2.0
        { rect: [center - width / 2.0, a[1] - 9, center + width / 2.0, a[1] + 9], gap: 8, segment: horizontal }
      end

      def route_pieces(points, label)
        return [points] unless label
        a, b = label[:segment]
        index = points.each_cons(2).to_a.index([a, b])
        left, right, y = label[:rect][0], label[:rect][2], a[1]
        before = points[0..index] + [[a[0] < b[0] ? left - label[:gap] : right + label[:gap], y]]
        after = [[a[0] < b[0] ? right + label[:gap] : left - label[:gap], y]] + points[(index + 1)..]
        [Geometry.compact(before), Geometry.compact(after)]
      end

      def ensure_route_separation!(routes)
        routes.each_with_index do |route, index|
          routes[0...index].each do |previous|
            route[:points].each_cons(2) do |a, b|
              previous[:points].each_cons(2) do |c, d|
                conflict = Geometry.parallel_conflict?(a, b, c, d, gap: PORT_GAP) || Geometry.crossing(a, b, c, d)
                next unless conflict
                raise LayoutError, 'Data-flow routes cross or cannot keep 12px parallel separation; split the diagram'
              end
            end
          end
        end
      end

      def place_legend(width)
        payloads = DataFlowDSL::PAYLOADS.select do |kind|
          @d.data_flow_transfers.any? { |item| item.input == kind || item.output == kind }
        end
        kinds = DataFlowDSL::HANDOFF_KINDS.select do |kind|
          @d.data_flow_handoffs.any? { |item| item.kind == kind }
        end
        payload_width = payloads.sum { |item| self.class.payload_legend_entry_width(item) }
        handoff_width = kinds.sum { |item| self.class.handoff_legend_entry_width(item) }
        available = width - 2 * OUTER_LEFT
        if [payload_width, handoff_width].max > available
          raise LayoutError, 'Data-flow legend cannot fit the measured canvas; split the diagram'
        end
        { y: STEP_HEADER + @d.data_flow_roles.size * ROLE_BAND + 12, height: 56, payloads: payloads, kinds: kinds }
      end

      def boundary(card, side, offset)
        cx = card[:x] + card[:width] / 2.0
        cy = card[:y] + card[:height] / 2.0
        case side
        when :top then [cx + offset, card[:y]]
        when :bottom then [cx + offset, card[:y] + card[:height]]
        when :left then [card[:x], cy + offset]
        when :right then [card[:x] + card[:width], cy + offset]
        end
      end

      def card_for(cards, transfer_id) = cards.find { |card| card[:transfer].id == transfer_id }
      def card_rect(card, padding = 0) = [card[:x] - padding, card[:y] - padding, card[:x] + card[:width] + padding, card[:y] + card[:height] + padding]

      def tracked_width(value, size, font, spacing)
        Text.width(value, size, font: font) + [value.each_char.count - 1, 0].max * spacing
      end
    end
  end
end
