# frozen_string_literal: true
module SlimGraphR
  module Layout
    GanttScene = Struct.new(
      :width, :height, :timeline_x, :timeline_width, :axis_y, :caption_y,
      :domain_start, :domain_finish, :ticks, :phase_zones, :tasks, :milestones, :markers,
      keyword_init: true
    )
    KanbanScene = Struct.new(:width, :height, :columns, keyword_init: true)

    class Gantt
      WIDTH = 900
      LABEL_X = 20
      LABEL_WIDTH = 164
      TIMELINE_X = 200
      TIMELINE_WIDTH = 680
      AXIS_Y = 28
      CAPTION_Y = 55
      PHASE_TOP = 108
      PHASE_HEADER = 28
      ROW_HEIGHT = 40
      BAR_HEIGHT = 24
      TRACK_HEIGHT = 72
      POINT_GAP = 12

      def initialize(diagram) = @d = diagram

      def call
        dates = @d.gantt_tasks.flat_map { |item| [date(item.start), date(item.finish)] } +
                @d.gantt_milestones.map { |item| date(item.on) } + @d.gantt_markers.map { |item| date(item.on) }
        @domain_start, @domain_finish = dates.minmax
        @domain_days = (@domain_finish - @domain_start).to_i
        phase_zones, tasks, track_y, cursor = place_phases
        milestones = place_milestones(track_y, cursor)
        markers = place_markers([cursor, milestones.map { |item| item[:track_bottom] }.max || cursor].max)
        ensure_point_density!(milestones + markers)
        bottom = [cursor, milestones.map { |item| item[:track_bottom] }.max || cursor].max + 16
        GanttScene.new(
          width: WIDTH, height: bottom, timeline_x: TIMELINE_X, timeline_width: TIMELINE_WIDTH,
          axis_y: AXIS_Y, caption_y: CAPTION_Y, domain_start: @domain_start, domain_finish: @domain_finish,
          ticks: calendar_ticks, phase_zones: phase_zones, tasks: tasks, milestones: milestones, markers: markers
        )
      end

      private

      def place_phases
        zones = []
        tasks = []
        track_y = {}
        cursor = PHASE_TOP
        @d.gantt_phases.each do |phase|
          phase_tasks = @d.gantt_tasks.select { |item| item.phase == phase.id }
          phase_points = @d.gantt_milestones.select { |item| item.phase == phase.id }
          label = phase.label.upcase
          if tracked_width(label, 9, :mono, 0.14) > LABEL_WIDTH
            raise LayoutError, "Gantt phase label #{phase.label.inspect} does not fit after uppercase tracking; shorten it"
          end
          zone_height = PHASE_HEADER + phase_tasks.size * ROW_HEIGHT + (phase_points.empty? ? 0 : TRACK_HEIGHT)
          zone_height = [zone_height, PHASE_HEADER + 16].max
          zones << { phase: phase, x: LABEL_X, y: cursor, width: WIDTH - 2 * LABEL_X, height: zone_height }
          phase_tasks.each_with_index do |task, index|
            row_y = cursor + PHASE_HEADER + index * ROW_HEIGHT
            label_lines = Text.wrap(task.label, LABEL_WIDTH, 11)
            if label_lines.size > 2
              raise LayoutError, "Gantt task label #{task.label.inspect} does not fit the 180px label column; shorten it"
            end
            x = scaled_x(date(task.start))
            finish_x = scaled_x(date(task.finish))
            width = finish_x - x
            if width < 1
              raise LayoutError, "Gantt task #{task.id} has a true bar width under one CSS pixel; split the plan or narrow the date range"
            end
            tasks << {
              task: task, x: x, y: row_y + 8, width: width, height: BAR_HEIGHT,
              label_lines: label_lines, label_y: row_y + (label_lines.one? ? 25 : 17),
              bar_text: Text.width(task.label, 10) + 16 <= width ? task.label : nil
            }
          end
          track_y["phase:#{phase.id}"] = cursor + PHASE_HEADER + phase_tasks.size * ROW_HEIGHT if phase_points.any?
          cursor += zone_height + 12
        end
        [zones, tasks, track_y, cursor]
      end

      def place_milestones(track_y, cursor)
        global = @d.gantt_milestones.any? { |item| item.phase.nil? }
        track_y['global:milestones'] = cursor if global
        placements = @d.gantt_milestones.map do |item|
          track = item.phase ? "phase:#{item.phase}" : 'global:milestones'
          start_y = track_y.fetch(track)
          x = scaled_x(date(item.on))
          width = Text.width(item.label, 10)
          raise LayoutError, "Gantt milestone label #{item.label.inspect} is too wide; shorten it" if width > 176
          {
            item: item, kind: :milestone, track: track, x: x, y: start_y + 16,
            label_width: width, track_bottom: start_y + TRACK_HEIGHT
          }
        end
        route_point_labels!(placements)
        placements
      end

      def place_markers(bottom)
        placements = @d.gantt_markers.map.with_index do |item, index|
          width = Text.width(item.label, 9, font: :mono)
          raise LayoutError, "Gantt marker label #{item.label.inspect} is too wide; shorten it" if width > 176
          {
            item: item, kind: :marker, track: 'global:markers', x: scaled_x(date(item.on)), y: AXIS_Y,
            label_width: width, label_y: 78 + index * 14, track_bottom: bottom
          }
        end
        route_point_labels!(placements, fixed_levels: true)
        placements
      end

      def route_point_labels!(placements, fixed_levels: false)
        placements.group_by { |item| item[:track] }.each_value do |track_items|
          used = []
          track_items.sort_by { |item| item[:x] }.each_with_index do |item, index|
            sides = item[:x] > TIMELINE_X + TIMELINE_WIDTH - item[:label_width] - 20 ? %i[left right] : %i[right left]
            candidates = sides.product(fixed_levels ? [index] : [0, 1, 2])
            chosen = candidates.find do |side, level|
              anchor_x = item[:x] + (side == :right ? 10 : -10)
              left = side == :right ? anchor_x : anchor_x - item[:label_width]
              baseline = item[:label_y] || item[:y] + 4 + level * 16
              rect = [left - 2, baseline - 11, left + item[:label_width] + 2, baseline + 3]
              left >= TIMELINE_X && rect[2] <= TIMELINE_X + TIMELINE_WIDTH && used.none? { |other| Geometry.overlaps?(rect, other) }
            end
            unless chosen
              raise LayoutError, 'Gantt labels cannot be routed clearly on the same track; split the plan or narrow the date range'
            end
            side, level = chosen
            item[:label_x] = item[:x] + (side == :right ? 10 : -10)
            item[:label_anchor] = side == :right ? 'start' : 'end'
            item[:label_y] ||= item[:y] + 4 + level * 16
            left = side == :right ? item[:label_x] : item[:label_x] - item[:label_width]
            used << [left - 2, item[:label_y] - 11, left + item[:label_width] + 2, item[:label_y] + 3]
          end
        end
      end

      def ensure_point_density!(items)
        items.group_by { |item| item[:track] }.each do |track, points|
          points.sort_by { |item| item[:x] }.each_cons(2) do |left, right|
            gap = right[:x] - left[:x]
            if left[:kind] == :milestone && right[:kind] == :milestone && gap < POINT_GAP
              raise LayoutError, "Gantt milestone diamonds overlap on the same track #{track}; split the plan or narrow the date range"
            end
            if left[:kind] == :marker && right[:kind] == :marker && gap < 2
              raise LayoutError, "Gantt marker lines overlap on the same track #{track}; split the plan or narrow the date range"
            end
          end
        end
      end

      def calendar_ticks
        return [{ date: @domain_start, label: @domain_start.iso8601, x: TIMELINE_X + TIMELINE_WIDTH / 2, anchor: 'middle' }] if @domain_days.zero?
        candidates = [@domain_start]
        if @domain_days <= 100
          current = @domain_start + ((1 - @domain_start.cwday) % 7)
          while current < @domain_finish
            candidates << current if current > @domain_start
            current += 7
          end
        else
          current = Date.new(@domain_start.year, @domain_start.month, 1) >> 1
          while current < @domain_finish
            candidates << current
            current >>= 1
          end
        end
        candidates << @domain_finish
        kept = []
        candidates.uniq.each do |item|
          x = scaled_x(item)
          next if kept.any? && x - kept.last[:x] < 88 && item != @domain_finish
          label = if item == @domain_start || item == @domain_finish || item.year != @domain_start.year
            item.iso8601
          else
            item.strftime('%m-%d')
          end
          kept << { date: item, label: label, x: x, anchor: item == @domain_start ? 'start' : item == @domain_finish ? 'end' : 'middle' }
        end
        kept.pop if kept.size > 1 && kept.last[:date] != @domain_finish && scaled_x(@domain_finish) - kept.last[:x] < 88
        unless kept.last[:date] == @domain_finish
          kept.pop if kept.size > 1 && scaled_x(@domain_finish) - kept.last[:x] < 88
          kept << { date: @domain_finish, label: @domain_finish.iso8601, x: scaled_x(@domain_finish), anchor: 'end' }
        end
        kept
      end

      def scaled_x(value)
        return TIMELINE_X + TIMELINE_WIDTH / 2 if @domain_days.zero?
        TIMELINE_X + (value - @domain_start).to_i.fdiv(@domain_days) * TIMELINE_WIDTH
      end

      def tracked_width(value, size, font, em)
        Text.width(value, size, font: font) + [value.each_char.count - 1, 0].max * size * em
      end

      def date(value) = Date.iso8601(value, Date::GREGORIAN)
    end

    class Kanban
      COLUMN_WIDTH = 240
      GUTTER = 32
      HEADER_HEIGHT = 48
      CARD_X_INSET = 16
      CARD_WIDTH = 208
      CARD_HEIGHT = 56
      CARD_GAP = 12

      def initialize(diagram) = @d = diagram

      def call
        cards = @d.kanban_columns.flat_map(&:cards)
        if cards.size > 12
          raise LayoutError, 'Kanban board limit is twelve cards; split the board without aggregating or dropping cards'
        end
        @d.kanban_columns.each do |column|
          if column.cards.size > 4
            raise LayoutError, "Kanban column #{column.id} has more than four cards; split the board without aggregation"
          end
        end
        max_cards = @d.kanban_columns.map { |item| item.cards.size }.max
        height = HEADER_HEIGHT + 16 + max_cards * CARD_HEIGHT + [max_cards - 1, 0].max * CARD_GAP + 16
        columns = @d.kanban_columns.each_with_index.map { |column, index| place_column(column, index, height) }
        KanbanScene.new(width: @d.kanban_columns.size * COLUMN_WIDTH + (@d.kanban_columns.size - 1) * GUTTER,
                        height: height, columns: columns)
      end

      private

      def place_column(column, index, height)
        x = index * (COLUMN_WIDTH + GUTTER)
        count_label = column.wip_limit ? "#{column.cards.size}/#{column.wip_limit}" : column.cards.size.to_s
        count_width = Text.width(count_label, 8, font: :mono) + (column.wip_limit ? 12 : 0)
        title_budget = COLUMN_WIDTH - 32 - count_width - 12
        if Text.width(column.label, 12) > title_budget
          raise LayoutError, "Kanban column label #{column.label.inspect} does not fit beside its honest count; shorten it"
        end
        placed_cards = column.cards.each_with_index.map do |card, row|
          title_lines = Text.wrap(card.label, CARD_WIDTH - 24, 12)
          if title_lines.size > 2
            raise LayoutError, "Kanban card title #{card.label.inspect} does not fit the fixed card; shorten it"
          end
          sublabel = [card.ticket, card.owner].compact.join(' · ')
          if !sublabel.empty? && Text.width(sublabel, 9, font: :mono) > CARD_WIDTH - 24
            raise LayoutError, "Kanban card sublabel #{sublabel.inspect} does not fit the fixed card; shorten ticket or owner"
          end
          {
            card: card, x: x + CARD_X_INSET, y: HEADER_HEIGHT + 16 + row * (CARD_HEIGHT + CARD_GAP),
            width: CARD_WIDTH, height: CARD_HEIGHT, title_lines: title_lines, sublabel: sublabel
          }
        end
        {
          column: column, x: x, y: 0, width: COLUMN_WIDTH, height: height,
          count_label: count_label, violation: column.wip_limit && column.cards.size > column.wip_limit,
          cards: placed_cards
        }
      end
    end
  end
end
