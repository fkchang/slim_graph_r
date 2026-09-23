# frozen_string_literal: true
module SlimGraphR
  class SVG
    private

    def draw_data_flow
      draw_data_flow_grid
      if @motion
        @s.routes.each { |route| motion_route_item(route[:handoff].from, route[:handoff].to) { draw_data_flow_route(route) } }
        @s.cards.each { |card| motion_item(card[:transfer].id) { draw_data_flow_card(card) } }
        @s.routes.each { |route| motion_route_item(route[:handoff].from, route[:handoff].to) { draw_data_flow_label(route) } if route[:label] }
      else
        @s.routes.each { |route| draw_data_flow_route(route) }
        @s.cards.each { |card| draw_data_flow_card(card) }
        @s.routes.each { |route| draw_data_flow_label(route) if route[:label] }
      end
      draw_data_flow_legend
    end

    def draw_data_flow_grid
      @s.steps.each do |entry|
        item = entry[:step]
        fill = item.focal ? 'var(--sgr-accent)' : 'var(--sgr-secondary)'
        text_fill = item.focal ? 'var(--sgr-paper)' : 'var(--sgr-muted)'
        header_x = entry[:x] + (entry[:width] - Layout::DataFlow::CARD_WIDTH) / 2.0
        rect(header_x, 4, Layout::DataFlow::CARD_WIDTH, 24, rx: 3, fill: fill,
             'fill-opacity': item.focal ? 1 : 0.45, 'data-sgr-step': item.id,
             'data-sgr-step-ordinal': item.ordinal, 'data-sgr-step-focal': item.focal)
        text(format('%02d · %s', item.ordinal, entry[:label]), entry[:x] + entry[:width] / 2.0, 20,
             class: "sgr-data-flow-step#{item.focal ? ' sgr-data-flow-step-focal' : ''}",
             fill: text_fill, 'text-anchor': 'middle', 'letter-spacing': 1.2)
      end
      @s.roles.each do |entry|
        item = entry[:role]
        line(entry[:x], entry[:y] + entry[:height], @s.width - 40, entry[:y] + entry[:height], 'var(--sgr-rule)')
        text(item.label.upcase, entry[:x], entry[:y] + 43, class: 'sgr-data-flow-role',
             'data-sgr-role': item.id, 'letter-spacing': 1.2)
      end
    end

    def draw_data_flow_route(route)
      item = route[:handoff]
      stroke, width, dash, marker = case item.kind
      when :trigger then ['var(--sgr-muted)', 1, '4 3', 'arrow-open']
      when :focal then ['var(--sgr-accent)', 1.6, nil, 'arrow-accent']
      when :publish then ['var(--sgr-link)', 1.2, nil, 'arrow-link']
      else ['var(--sgr-muted)', 1, nil, 'arrow']
      end
      add %(<g data-sgr-data-flow-route="#{esc("#{item.from}-#{item.to}")}" data-sgr-handoff-kind="#{item.kind}" data-sgr-route-orthogonal="true">)
      route[:pieces].each_with_index do |piece, index|
        marker_attr = index == route[:pieces].size - 1 ? "url(##{@id}-#{marker})" : nil
        add %(<path #{attrs('data-sgr-route-segment': index + 1, 'data-sgr-rounded-bends': true,
                            d: data_flow_rounded_path(piece), fill: 'none',
                            stroke: stroke, 'stroke-width': width, 'stroke-dasharray': dash,
                            'marker-end': marker_attr)}/>)
      end
      sx, sy = route[:source_port]
      tx, ty = route[:target_port]
      add %(<circle data-sgr-source-port="#{esc(item.from)}" cx="#{coord(sx)}" cy="#{coord(sy)}" r="1.75" fill="#{stroke}"/>)
      add %(<circle data-sgr-target-port="#{esc(item.to)}" cx="#{coord(tx)}" cy="#{coord(ty)}" r="1.75" fill="#{stroke}"/>)
      add '</g>'
    end

    def draw_data_flow_card(card)
      item = card[:transfer]
      fill = item.focal ? 'var(--sgr-tint)' : 'var(--sgr-paper)'
      stroke = item.focal ? 'var(--sgr-accent)' : 'var(--sgr-ink)'
      rect(card[:x], card[:y], card[:width], card[:height], rx: 6, fill: fill, stroke: stroke,
           'stroke-width': item.focal ? 1.5 : 1, 'data-sgr-transfer': item.id,
           'data-sgr-cell': "#{item.role}:#{item.step}", 'data-sgr-transfer-focal': item.focal)
      role = @d.data_flow_roles.find { |candidate| candidate.id == item.role }
      chip_width = Layout::DataFlow.chip_width(role.key)
      rect(card[:x] + 6, card[:y] + 5, chip_width, Layout::DataFlow::CHIP_HEIGHT, rx: 2, fill: 'var(--sgr-secondary)',
           stroke: item.focal ? 'var(--sgr-accent)' : 'var(--sgr-rule)', 'stroke-width': 0.7,
           'data-sgr-role-key': role.key)
      text(role.key, card[:x] + 6 + chip_width / 2.0, card[:y] + 17,
           class: 'sgr-data-flow-key', 'text-anchor': 'middle')
      title_x = item.detail ? card[:x] + 8 : card[:x] + 6 + chip_width + 5
      title_y = item.detail ? card[:y] + 32 : card[:y] + 17
      card[:title_lines].each_with_index do |value, index|
        text(value, index.zero? ? title_x : card[:x] + 8, title_y + index * 13,
             class: "#{item.detail ? 'sgr-data-flow-detail-title' : 'sgr-data-flow-name'}#{item.focal ? ' sgr-emphasis' : ''}")
      end
      if item.detail
        text(item.detail, card[:x] + 8, card[:y] + 48, class: 'sgr-data-flow-detail', 'data-sgr-transfer-detail': item.id)
        text(item.tool, card[:x] + 8, card[:y] + 64, class: 'sgr-data-flow-tool')
        draw_data_flow_payload(card, item.input, :input, y: card[:y] + 84) if item.input
        draw_data_flow_payload(card, item.output, :output, y: card[:y] + 84) if item.output
      else
        text(item.tool, card[:x] + 8, card[:y] + 46, class: 'sgr-data-flow-tool')
        draw_data_flow_payload(card, item.input, :input) if item.input
        draw_data_flow_payload(card, item.output, :output) if item.output
      end
    end

    def draw_data_flow_payload(card, payload, side, y: card[:y] + 55)
      label = payload.to_s.upcase
      width = Layout::DataFlow.chip_width(label)
      x = side == :input ? card[:x] + 7 : card[:x] + card[:width] - 7 - width
      rect(x, y, width, Layout::DataFlow::CHIP_HEIGHT, rx: 2, fill: "var(--sgr-payload-#{payload})",
           'data-sgr-payload-side': side, 'data-sgr-payload': payload)
      text(label, x + width / 2.0, y + 12, class: 'sgr-data-flow-payload', 'text-anchor': 'middle')
    end

    def draw_data_flow_label(route)
      item = route[:handoff]
      x, y, right, bottom = route[:label][:rect]
      rect(x, y, right - x, bottom - y, rx: 3, fill: 'var(--sgr-paper)',
           'data-sgr-focal-label-mask': 'true', 'data-sgr-label-gap': route[:label][:gap])
      text(item.label, (x + right) / 2.0, y + 12, class: 'sgr-data-flow-route-label',
           'text-anchor': 'middle')
    end

    def draw_data_flow_legend
      y = @s.legend[:y]
      x = 20
      @s.legend[:payloads].each do |payload|
        add %(<circle data-sgr-legend-payload="#{payload}" cx="#{x + 5}" cy="#{y + 9}" r="5" fill="var(--sgr-payload-#{payload})"/>)
        text(payload.to_s.upcase, x + 14, y + 12, class: 'sgr-data-flow-legend')
        x += Layout::DataFlow.payload_legend_entry_width(payload)
      end
      x = 20
      @s.legend[:kinds].each do |kind|
        color = kind == :focal ? 'var(--sgr-accent)' : kind == :publish ? 'var(--sgr-link)' : 'var(--sgr-muted)'
        dash = kind == :trigger ? '4 3' : nil
        add %(<line #{attrs('data-sgr-legend-handoff': kind, x1: x, y1: y + 38, x2: x + 24, y2: y + 38,
                            stroke: color, 'stroke-width': kind == :focal ? 1.6 : 1,
                            'stroke-dasharray': dash)}/>)
        text(kind.to_s.upcase, x + 31, y + 41, class: 'sgr-data-flow-legend')
        x += Layout::DataFlow.handoff_legend_entry_width(kind)
      end
    end

    def data_flow_description
      return @d.description if @d.description
      roles = @d.data_flow_roles.map(&:label).join('; ')
      steps = @d.data_flow_steps.map { |item| "#{item.ordinal} #{item.label}#{item.focal ? ', focal' : ''}" }.join('; ')
      role_names = @d.data_flow_roles.to_h { |item| [item.id, item.label] }
      step_names = @d.data_flow_steps.to_h { |item| [item.id, item.label] }
      transfer_names = @d.data_flow_transfers.to_h { |item| [item.id, item.label] }
      transfers = @d.data_flow_transfers.map do |item|
        "#{item.label}#{item.detail ? ": #{item.detail}" : ''} by #{role_names.fetch(item.role)} at #{step_names.fetch(item.step)} using #{item.tool}; " \
          "input #{item.input || 'not declared'}; output #{item.output || 'not declared'}#{item.focal ? '; focal' : ''}."
      end.join(' ')
      handoffs = @d.data_flow_handoffs.map do |item|
        "#{item.kind} handoff from #{transfer_names.fetch(item.from)} to #{transfer_names.fetch(item.to)}" \
          "#{item.label ? ", label #{item.label}" : ''}."
      end.join(' ')
      "Data flow. Roles in order: #{roles}. Stages in order: #{steps}. Transfers: #{transfers} Handoffs: #{handoffs} " \
        'The focal step, transfer, and handoff are one linked focal claim.'
    end

    def data_flow_rounded_path(points)
      commands = ["M #{coord(points[0][0])} #{coord(points[0][1])}"]
      current = points.first
      points.each_cons(3) do |a, corner, following|
        first_length = (a[0] - corner[0]).abs + (a[1] - corner[1]).abs
        next_length = (following[0] - corner[0]).abs + (following[1] - corner[1]).abs
        radius = [6, first_length / 2.0, next_length / 2.0].min
        before = [corner[0] + (a[0] <=> corner[0]) * radius, corner[1] + (a[1] <=> corner[1]) * radius]
        after = [corner[0] + (following[0] <=> corner[0]) * radius, corner[1] + (following[1] <=> corner[1]) * radius]
        commands << data_flow_straight_command(current, before)
        commands << " Q #{coord(corner[0])} #{coord(corner[1])} #{coord(after[0])} #{coord(after[1])}"
        current = after
      end
      commands << data_flow_straight_command(current, points.last)
      commands.join
    end

    def data_flow_straight_command(from, to)
      return '' if from == to
      if from[1] == to[1]
        " H #{coord(to[0])}"
      elsif from[0] == to[0]
        " V #{coord(to[1])}"
      else
        raise LayoutError, 'Data-flow route contains a diagonal segment; split the diagram'
      end
    end

    def coord(value)
      value.respond_to?(:to_i) && value == value.to_i ? value.to_i : value.round(3)
    end
  end
end
