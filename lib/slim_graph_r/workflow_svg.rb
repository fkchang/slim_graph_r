# frozen_string_literal: true
module SlimGraphR
  class SVG
    private

    def draw_workflow
      draw_workflow_grid
      @s.routes.each { |route| draw_workflow_route(route) }
      @s.boxes.each { |box| draw_workflow_card(box) }
      draw_workflow_legend
    end

    def draw_workflow_grid
      @s.workflow_lanes.each_with_index do |item, index|
        lane = item[:lane]
        _left, top, _right, bottom = item[:rect]
        rect(140, top, @s.width - 140, bottom - top, fill: 'var(--sgr-secondary)', opacity: index.even? ? 0.16 : 0.06,
             'data-sgr-workflow-lane-fill': lane.id)
        line(0, top, @s.width, top, 'var(--sgr-rule)')
        text(lane.label.upcase, 70, top + 44, class: 'sgr-workflow-lane', 'text-anchor': 'middle', 'data-sgr-lane': lane.id)
      end
      line(0, @s.workflow_grid_bottom, @s.width, @s.workflow_grid_bottom, 'var(--sgr-rule)')
      line(140, @s.workflow_header_height, 140, @s.workflow_grid_bottom, 'var(--sgr-rule)')
      @s.workflow_stages.each do |item|
        chip_width = Layout::Workflow.chip_width(item[:number])
        rect(item[:cx] - chip_width / 2, 8, chip_width, Layout::Workflow::CHIP_HEIGHT, rx: 8,
             fill: item[:focal] ? 'var(--sgr-tint)' : 'var(--sgr-secondary)',
             stroke: item[:focal] ? 'var(--sgr-accent)' : 'none',
             'data-sgr-stage': item[:id], 'data-sgr-stage-number': item[:number], 'data-sgr-focal': item[:focal])
        text(item[:number], item[:cx], 19, class: item[:focal] ? 'sgr-workflow-stage sgr-emphasis' : 'sgr-workflow-stage', 'text-anchor': 'middle')
        text(item[:label].upcase, item[:cx], 33, class: item[:focal] ? 'sgr-workflow-stage sgr-emphasis' : 'sgr-workflow-stage', 'text-anchor': 'middle')
      end
    end

    def draw_workflow_route(route)
      style = route.style
      stroke = style == :accent ? 'var(--sgr-accent)' : 'var(--sgr-muted)'
      marker = style == :accent ? 'arrow-accent' : (style == :trigger ? 'arrow-sm' : 'arrow')
      add %(<path #{attrs(
        d: rounded_path(route.points), fill: 'none', stroke: stroke, 'stroke-width': style == :accent ? 1.2 : 1,
        'stroke-dasharray': %i[trigger revision].include?(style) ? '4 3' : nil, 'marker-end': "url(##{@id}-#{marker})",
        'data-sgr-workflow-connector': "#{route.edge.from}-#{route.edge.to}", 'data-sgr-workflow-style': style
      )}/>)
      return unless route.label_box
      left, top, right, bottom = route.label_box[:rect]
      rect(left, top, right - left, bottom - top, rx: 4, fill: 'var(--sgr-paper)', stroke: 'var(--sgr-rule)')
      text(route.edge.label.upcase, (left + right) / 2, top + 12, class: 'sgr-workflow-trigger-label', 'text-anchor': 'middle')
    end

    def draw_workflow_card(box)
      card = box.node
      focal = card.focal
      attributes = {
        x: box.x, y: box.y, width: box.width, height: box.height, rx: 6,
        fill: focal ? 'var(--sgr-tint)' : 'var(--sgr-paper)', stroke: focal ? 'var(--sgr-accent)' : 'var(--sgr-rule)',
        'stroke-width': focal ? 1.4 : 1, 'data-sgr-focal': focal
      }
      attributes[@d.type == :process ? :'data-sgr-operation' : :'data-sgr-activity'] = card.id
      attributes[:'data-sgr-tool'] = card.tool if card.tool
      attributes[:'data-sgr-input'] = card.input if card.input
      attributes[:'data-sgr-output'] = card.output if card.output
      add %(<rect #{attrs(attributes)}/>)
      if @d.type == :process
        lane = @d.workflow_lanes.find { |item| item.id == card.lane }
        chip_width = Layout::Workflow.chip_width(lane.key)
        rect(box.x + 4, box.y + 4, chip_width, Layout::Workflow::CHIP_HEIGHT, rx: 2, fill: focal ? 'var(--sgr-accent)' : 'var(--sgr-secondary)',
             'data-sgr-lane-key': lane.key)
        text(lane.key, box.x + 4 + chip_width / 2.0, box.y + 16, class: 'sgr-workflow-key',
             fill: focal ? 'var(--sgr-paper)' : 'var(--sgr-muted)', 'text-anchor': 'middle')
        text(card.label, box.x + 10 + chip_width, box.y + 17, class: 'sgr-workflow-card-name')
        detail_y = 35
        text(card.detail, box.center[0], box.y + detail_y, class: 'sgr-workflow-detail', 'text-anchor': 'middle') if card.detail
        tool_y = card.detail ? 46 : 36
        text(card.tool, box.center[0], box.y + tool_y, class: 'sgr-workflow-tool', 'text-anchor': 'middle')
        draw_payload_chip(card.input, box, 'input') if card.input
        draw_payload_chip(card.output, box, 'output') if card.output
      else
        text(card.label, box.center[0], box.y + (card.detail ? 28 : 37), class: 'sgr-workflow-card-name', 'text-anchor': 'middle')
        text(card.detail, box.center[0], box.y + 46, class: 'sgr-workflow-detail', 'text-anchor': 'middle') if card.detail
      end
    end

    def draw_payload_chip(code, box, direction)
      width = Layout::Workflow.chip_width(code)
      x = direction == 'input' ? box.x + 4 : box.right - 4 - width
      y = box.y + 47
      rect(x, y, width, Layout::Workflow::CHIP_HEIGHT, rx: 2, fill: "var(--sgr-payload-#{code.downcase})", 'data-sgr-payload': code, 'data-sgr-payload-direction': direction)
      text(code, x + width / 2.0, y + 12, class: 'sgr-workflow-payload-text', 'text-anchor': 'middle')
    end

    def draw_workflow_legend
      y = @s.workflow_grid_bottom + (@s.workflow_return_y ? 40 : 0) + 16
      @s.workflow_legend_rows.each do |row|
        row[:lines].each do |entries|
          text(row[:label], 144, y, class: 'sgr-workflow-legend', 'data-sgr-legend-kind': row[:kind])
          x = 220
          entries.each do |entry|
            draw_workflow_legend_entry(row[:kind], entry, x, y)
            x += entry[:width] + 8
          end
          y += 24
        end
      end
    end

    def draw_workflow_legend_entry(kind, entry, x, y)
      symbol_width = Layout::Workflow.legend_symbol_width(kind, entry[:code])
      case kind
      when :steps
        rect(x, y - 15, symbol_width, Layout::Workflow::CHIP_HEIGHT, rx: 8, fill: entry[:focal] ? 'var(--sgr-tint)' : 'var(--sgr-secondary)', stroke: entry[:focal] ? 'var(--sgr-accent)' : 'none')
        text(entry[:code], x + symbol_width / 2.0, y - 3, class: entry[:focal] ? 'sgr-workflow-legend sgr-emphasis' : 'sgr-workflow-legend', 'text-anchor': 'middle')
      when :payload
        rect(x, y - 15, symbol_width, Layout::Workflow::CHIP_HEIGHT, rx: 2, fill: "var(--sgr-payload-#{entry[:code].downcase})", 'data-sgr-legend-payload': entry[:code])
        text(entry[:code], x + symbol_width / 2.0, y - 3, class: 'sgr-workflow-payload-text', 'text-anchor': 'middle')
      when :flow
        stroke = entry[:code] == :accent ? 'var(--sgr-accent)' : 'var(--sgr-muted)'
        line(x, y - 6, x + 20, y - 6, stroke, dashed: %i[trigger revision].include?(entry[:code]), dash_pattern: '4 3')
      end
      text(entry[:label], x + symbol_width + 8, y - 2, class: 'sgr-workflow-legend', 'data-sgr-legend-entry': entry[:code])
    end

    def workflow_description
      cards = @d.type == :process ? @d.operations : @d.activities
      lanes = @d.workflow_lanes.map { |item| "#{item.label}#{item.key ? " (#{item.key})" : ''}" }.join('; ')
      stages = @d.workflow_stages.map { |item| "Stage #{item.number}, #{item.label}#{item.focal ? ', focal' : ''}." }.join(' ')
      work = cards.map do |card|
        lane = @d.workflow_lanes.find { |item| item.id == card.lane }
        parts = ["#{lane.label} performs #{card.label}#{card.focal ? ', focal' : ''} in #{card.stage}"]
        parts << "tool #{card.tool}" if card.tool
        parts << card.detail if card.detail
        parts << "input #{card.input}" if card.input
        parts << "output #{card.output}" if card.output
        "#{parts.join(', ')}."
      end.join(' ')
      names = cards.to_h { |card| [card.id, card.label] }
      handoffs = @d.workflow_handoffs.map do |item|
        route = @s.routes.find { |candidate| candidate.edge.equal?(item) }
        label = item.label ? " labelled #{item.label}" : ''
        dashed = item.dashed ? ', dashed' : ''
        "#{names.fetch(item.from)} to #{names.fetch(item.to)}, #{route.style} handoff#{label}#{dashed}."
      end.join(' ')
      trigger = @d.workflow_trigger && "Return trigger #{@d.workflow_trigger.label} from #{names.fetch(@d.workflow_trigger.from)} to #{names.fetch(@d.workflow_trigger.to)}, neutral dashed."
      generated = "#{@d.type == :process ? 'Process workflow' : 'Swimlane workflow'}. Lanes: #{lanes}. #{stages} #{work} Empty cells mean no work by that actor. Handoffs: #{handoffs} #{trigger}".strip
      [@d.description, generated].compact.join(' ')
    end
  end
end
