# frozen_string_literal: true
module SlimGraphR
  class SVG
    private

    def draw_planning_board
      @d.type == :gantt ? draw_gantt : draw_kanban
    end

    def draw_gantt
      line(@s.timeline_x, @s.axis_y, @s.timeline_x + @s.timeline_width, @s.axis_y, 'var(--sgr-rule)')
      @s.ticks.each do |tick|
        x = planning_coord(tick[:x])
        line(x, @s.axis_y - 3, x, @s.axis_y + 3, 'var(--sgr-rule)')
        text(tick[:label], x, @s.axis_y - 8, class: 'sgr-gantt-date', 'text-anchor': tick[:anchor],
             'data-sgr-gantt-tick': tick[:date].iso8601, 'data-sgr-x': x)
      end
      text('Task bars include start; finish date is excluded', @s.timeline_x, @s.caption_y,
           class: 'sgr-gantt-caption', 'data-sgr-gantt-convention': 'finish-exclusive')
      add %(<g data-sgr-domain-start="#{@s.domain_start.iso8601}" data-sgr-domain-finish="#{@s.domain_finish.iso8601}">)
      @s.phase_zones.each do |zone|
        phase = zone[:phase]
        rect(zone[:x], zone[:y], zone[:width], zone[:height], rx: 6, fill: 'var(--sgr-secondary)',
             'fill-opacity': 0.24, stroke: 'var(--sgr-rule)', 'stroke-opacity': 0.55,
             'data-sgr-gantt-phase': phase.id)
        text(phase.label.upcase, zone[:x] + 8, zone[:y] + 17, class: 'sgr-gantt-phase',
             'data-sgr-phase-label': phase.label.upcase)
      end
      @s.markers.each { |entry| draw_gantt_marker(entry) }
      @s.tasks.each { |entry| draw_gantt_task(entry) }
      @s.milestones.each { |entry| draw_gantt_milestone(entry) }
      add '</g>'
    end

    def draw_gantt_task(entry)
      task = entry[:task]
      x = planning_coord(entry[:x])
      width = planning_coord(entry[:width])
      fill = task.focal ? 'var(--sgr-tint)' : 'var(--sgr-muted)'
      stroke = task.focal ? 'var(--sgr-accent)' : 'var(--sgr-muted)'
      rect(x, entry[:y], width, entry[:height], rx: 4, fill: fill, 'fill-opacity': task.focal ? 1 : 0.15,
           stroke: stroke, 'stroke-width': 1, 'data-sgr-gantt-task': task.id, 'data-sgr-start': task.start,
           'data-sgr-finish-exclusive': task.finish, 'data-sgr-phase': task.phase, 'data-sgr-focal': task.focal,
           'data-sgr-x': x, 'data-sgr-width': width)
      entry[:label_lines].each_with_index do |value, index|
        text(value, 20, entry[:label_y] + index * 13, class: "sgr-gantt-task-label#{task.focal ? ' sgr-emphasis' : ''}",
             'data-sgr-task-label': task.id)
      end
      if entry[:bar_text]
        text(entry[:bar_text], planning_coord(entry[:x] + 8), entry[:y] + 16.5,
             class: "sgr-gantt-bar-label#{task.focal ? ' sgr-emphasis' : ''}")
      end
    end

    def draw_gantt_milestone(entry)
      item = entry[:item]
      x = planning_coord(entry[:x])
      y = entry[:y]
      points = [[x, y - 6], [x + 6, y], [x, y + 6], [x - 6, y]].map { |point| point.join(',') }.join(' ')
      add %(<polygon #{attrs(points: points, fill: 'var(--sgr-tint)', stroke: 'var(--sgr-accent)', 'stroke-width': 1.2,
                            'data-sgr-gantt-milestone': item.id, 'data-sgr-date': item.on,
                            'data-sgr-phase': item.phase, 'data-sgr-track': entry[:track], 'data-sgr-x': x)}/>)
      leader_end = entry[:label_anchor] == 'start' ? entry[:label_x] - 2 : entry[:label_x] + 2
      line(x, y, planning_coord(leader_end), entry[:label_y] - 4, 'var(--sgr-accent)')
      text(item.label, planning_coord(entry[:label_x]), entry[:label_y], class: 'sgr-gantt-point-label',
           'text-anchor': entry[:label_anchor])
    end

    def draw_gantt_marker(entry)
      item = entry[:item]
      x = planning_coord(entry[:x])
      caption_left = @s.timeline_x - 4
      caption_right = @s.timeline_x + Text.width('Task bars include start; finish date is excluded', 9, font: :mono) + 4
      if x.between?(caption_left, caption_right)
        draw_gantt_marker_segment(item, x, @s.axis_y, 41, 'before-caption')
        draw_gantt_marker_segment(item, x, 62, entry[:track_bottom], 'after-caption')
      else
        draw_gantt_marker_segment(item, x, @s.axis_y, entry[:track_bottom], 'full')
      end
      leader_end = entry[:label_anchor] == 'start' ? entry[:label_x] - 2 : entry[:label_x] + 2
      line(x, entry[:label_y] - 4, planning_coord(leader_end), entry[:label_y] - 4, 'var(--sgr-muted)')
      text(item.label, planning_coord(entry[:label_x]), entry[:label_y], class: 'sgr-gantt-marker-label',
           'text-anchor': entry[:label_anchor], 'data-sgr-gantt-marker': item.id,
           'data-sgr-date': item.on, 'data-sgr-track': entry[:track], 'data-sgr-x': x)
    end

    def draw_kanban
      @s.columns.each do |entry|
        column = entry[:column]
        rect(entry[:x], entry[:y], entry[:width], entry[:height], fill: 'var(--sgr-secondary)', 'fill-opacity': 0.22,
             'data-sgr-column': column.id, 'data-sgr-column-count': column.cards.size,
             'data-sgr-wip-limit': column.wip_limit)
        text(column.label, entry[:x] + 16, 28, class: 'sgr-kanban-column-label')
        draw_kanban_count(entry)
        line(entry[:x], 48, entry[:x] + entry[:width], 48, 'var(--sgr-rule)')
        entry[:cards].each { |card_entry| draw_kanban_card(card_entry) }
      end
    end

    def draw_kanban_count(entry)
      column = entry[:column]
      x = entry[:x] + entry[:width] - 16
      unless column.wip_limit
        text(entry[:count_label], x, 27, class: 'sgr-kanban-count', 'text-anchor': 'end',
             'data-sgr-wip-label': entry[:count_label], 'data-sgr-wip-known': false)
        return
      end
      chip_width = Text.grid(Text.width(entry[:count_label], 8, font: :mono) + 12)
      rect(x - chip_width, 14, chip_width, 18, rx: 2, fill: 'var(--sgr-paper)',
           stroke: entry[:violation] ? 'var(--sgr-accent)' : 'var(--sgr-rule)',
           'data-sgr-wip-label': entry[:count_label], 'data-sgr-wip-known': true,
           'data-sgr-wip-violation': !!entry[:violation])
      text(entry[:count_label], x - chip_width / 2, 26, class: "sgr-kanban-count#{entry[:violation] ? ' sgr-emphasis' : ''}",
           'text-anchor': 'middle')
    end

    def draw_kanban_card(entry)
      card = entry[:card]
      fill, stroke, dash = {
        default: ['var(--sgr-paper)', 'var(--sgr-ink)', nil],
        blocked: ['var(--sgr-tint)', 'var(--sgr-accent)', '4 4'],
        waiting: ['var(--sgr-secondary)', 'var(--sgr-rule)', '4 3'],
        done: ['var(--sgr-secondary)', 'var(--sgr-muted)', nil]
      }.fetch(card.state)
      rect(entry[:x], entry[:y], entry[:width], entry[:height], rx: 6, fill: fill, stroke: stroke,
           'stroke-width': 1, 'stroke-dasharray': dash, 'data-sgr-card': card.id,
           'data-sgr-card-state': card.state, 'data-sgr-card-focal': card.focal)
      if card.state == :blocked
        rect(entry[:x], entry[:y], 4, entry[:height], rx: 2, fill: 'var(--sgr-accent)',
             'data-sgr-blocked-bar': card.id)
      end
      if card.focal
        rect(entry[:x] - 3, entry[:y] - 3, entry[:width] + 6, entry[:height] + 6, rx: 8,
             fill: 'none', stroke: 'var(--sgr-ink)', 'stroke-width': 2, 'data-sgr-focal-ring': card.id)
      end
      title_y = entry[:y] + (entry[:title_lines].one? ? (entry[:sublabel].empty? ? 33 : 23) : 17)
      entry[:title_lines].each_with_index do |value, index|
        text(value, entry[:x] + 12, title_y + index * 15, class: 'sgr-kanban-card-title')
      end
      unless entry[:sublabel].empty?
        text(entry[:sublabel], entry[:x] + 12, entry[:y] + 47, class: 'sgr-kanban-card-meta',
             'data-sgr-card-metadata': card.id)
      end
    end

    def planning_board_description
      return @d.description if @d.description
      generated = if @d.type == :gantt
        phases = @d.gantt_phases.map do |phase|
          tasks = @d.gantt_tasks.select { |item| item.phase == phase.id }.map do |item|
            "#{item.label}, #{item.start} through finish boundary #{item.finish}#{item.focal ? ', focal' : ''}"
          end
          "#{phase.label}: #{tasks.empty? ? 'no tasks' : tasks.join('; ')}"
        end.join('. ')
        milestones = @d.gantt_milestones.map do |item|
          "#{item.label} on #{item.on}#{item.phase ? " in #{item.phase}" : ', global'}"
        end.join('; ')
        markers = @d.gantt_markers.map { |item| "#{item.label} on #{item.on}" }.join('; ')
        "Gantt calendar plan. Task bars include start; finish date is excluded. Declaration-order phases and tasks: #{phases}. Milestones: #{milestones.empty? ? 'none' : milestones}. Markers: #{markers.empty? ? 'none' : markers}."
      else
        columns = @d.kanban_columns.map do |column|
          count = if column.wip_limit
            "#{column.cards.size} of limit #{column.wip_limit}#{column.cards.size > column.wip_limit ? ', violation' : ''}"
          else
            "#{column.cards.size}, no supplied WIP limit"
          end
          cards = column.cards.map do |card|
            metadata = [card.ticket && "ticket #{card.ticket}", card.owner && "owner #{card.owner}"].compact
            "#{card.label}, #{card.state}#{card.focal ? ', focal' : ''}#{metadata.empty? ? '' : ", #{metadata.join(', ')}"}"
          end
          "#{column.label}: #{count}; cards in supplied order: #{cards.empty? ? 'none' : cards.join('; ')}"
        end.join('. ')
        "Kanban state census with no connectors. Columns in supplied order: #{columns}."
      end
      generated
    end

    def draw_gantt_marker_segment(item, x, y1, y2, segment)
      add %(<line #{attrs('data-sgr-gantt-marker-line': item.id, 'data-sgr-marker-segment': segment,
                          x1: x, y1: y1, x2: x, y2: y2, stroke: 'var(--sgr-muted)',
                          'stroke-width': 1, 'stroke-dasharray': '4 4')}/>)
    end

    def planning_coord(value)
      number = value.is_a?(Float) ? value.round(6) : value
      number.respond_to?(:to_i) && number == number.to_i ? number.to_i : number
    end
  end
end
