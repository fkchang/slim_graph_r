# frozen_string_literal: true
module SlimGraphR
  module Layout
    class Workflow
      LABEL_WIDTH = 140
      STAGE_WIDTH = 112
      RIGHT_PAD = 28
      HEADER_HEIGHT = 36
      LANE_HEIGHT = 80
      CARD_WIDTH = 100
      CARD_HEIGHT = 64
      RETURN_HEIGHT = 40
      LEGEND_ROW_HEIGHT = 24
      CHIP_TEXT_SIZE = 12
      CHIP_HORIZONTAL_PADDING = 12
      CHIP_HEIGHT = 16

      def self.chip_width(value)
        Text.grid(Text.width(value.to_s, CHIP_TEXT_SIZE, font: :mono) + CHIP_HORIZONTAL_PADDING)
      end

      def self.legend_symbol_width(kind, code)
        %i[steps payload].include?(kind) ? chip_width(code) : 20
      end

      def self.legend_entry_width(kind, entry)
        Text.grid(legend_symbol_width(kind, entry[:code]) + 8 + Text.width(entry[:label], 12, font: :mono))
      end

      def initialize(diagram) = @d = diagram

      def call
        @cards = @d.type == :process ? @d.operations : @d.activities
        @card_width = measured_card_width
        @stage_width = measured_stage_width
        nominal_width = LABEL_WIDTH + @d.workflow_stages.size * @stage_width + RIGHT_PAD
        # Text.wrap budgets include an inter-word trailing-space allowance while building a line.
        title_width = Text.grid(Text.width(@d.title, 30, font: @d.style_profile.heading_font) + 104)
        @width = [360, nominal_width, title_width].max
        @grid_bottom = HEADER_HEIGHT + @d.workflow_lanes.size * LANE_HEIGHT
        @return_y = @d.workflow_trigger ? @grid_bottom + 16 : nil
        boxes = place_boxes
        routes = place_routes(boxes)
        legend_rows = legend_rows(routes)
        legend_top = @grid_bottom + (@return_y ? RETURN_HEIGHT : 0)
        height = legend_top + legend_rows.sum { |row| row[:lines].size * LEGEND_ROW_HEIGHT } + 16
        validate_routes!(routes, boxes, legend_top)
        Scene.new(
          boxes: boxes, routes: routes, zones: [], width: @width, height: height, lifelines: [], events: [],
          activations: [], fragments: [], callouts: [], footers: [], legend: [],
          workflow_lanes: lane_regions, workflow_stages: stage_headers,
          workflow_header_height: HEADER_HEIGHT, workflow_lane_height: LANE_HEIGHT,
          workflow_grid_bottom: @grid_bottom, workflow_return_y: @return_y,
          workflow_legend_rows: legend_rows
        )
      end

      private

      def lane_regions
        @d.workflow_lanes.each_with_index.map do |lane, index|
          ensure_fits!(lane.label.upcase, 120, 12, :mono, "lane label #{lane.label.inspect}")
          top = HEADER_HEIGHT + index * LANE_HEIGHT
          { lane: lane, rect: [0, top, @width, top + LANE_HEIGHT], content_rect: [LABEL_WIDTH, top, @width, top + LANE_HEIGHT] }
        end
      end

      def stage_headers
        @d.workflow_stages.each_with_index.map do |stage, index|
          ensure_fits!(stage.label.upcase, @stage_width - 12, 12, :mono, "stage label #{stage.label.inspect}")
          { stage: stage, id: stage.id, label: stage.label, number: index + 1, cx: stage_center(index), focal: stage.focal }
        end
      end

      def place_boxes
        @cards.map do |card|
          lane_index = @d.workflow_lanes.index { |item| item.id == card.lane }
          stage_index = @d.workflow_stages.index { |item| item.id == card.stage }
          title_width = @card_width - 12
          if @d.type == :process
            lane = @d.workflow_lanes.find { |item| item.id == card.lane }
            title_width = @card_width - self.class.chip_width(lane.key) - 14
          end
          ensure_fits!(card.label, title_width, 14, :sans, "card label #{card.label.inspect}")
          ensure_fits!(card.detail, @card_width - 12, 12, :mono, "detail #{card.detail.inspect}") if card.detail
          ensure_fits!(card.tool, @card_width - 12, 12, :mono, "tool #{card.tool.inspect}") if card.tool
          Box.new(
            node: card, x: stage_center(stage_index) - @card_width / 2,
            y: HEADER_HEIGHT + lane_index * LANE_HEIGHT + 8,
            width: @card_width, height: CARD_HEIGHT, lines: [card.label],
            details: card.detail ? [card.detail] : [], shape: :workflow_card
          )
        end
      end

      def place_routes(boxes)
        routes = @d.workflow_handoffs.map do |edge|
          source, target = boxes_for(boxes, edge)
          style = effective_style(edge)
          points = forward_points(source, target)
          Route.new(edge: edge, points: points, style: style,
                    label_box: edge.label && workflow_label_box(edge, points, boxes))
        end
        if @d.workflow_trigger
          source, target = boxes_for(boxes, @d.workflow_trigger)
          points = [[source.center[0], source.bottom], [source.center[0], @return_y], [target.center[0], @return_y], [target.center[0], target.bottom]]
          label_width = Text.grid(Text.width(@d.workflow_trigger.label, 12, font: :mono) + 12)
          label_x = (source.center[0] + target.center[0]) / 2
          max_label_width = 2 * [label_x - 8, @width - label_x - 8].min
          if label_width > max_label_width
            raise LayoutError, 'Process return trigger label does not fit the reserved return band; shorten it'
          end
          routes << Route.new(
            edge: @d.workflow_trigger, points: points, style: :trigger,
            label_box: { rect: [label_x - label_width / 2, @return_y - 9, label_x + label_width / 2, @return_y + 9],
                         lines: [@d.workflow_trigger.label] }
          )
        end
        routes
      end

      def forward_points(source, target)
        return [[source.right, source.center[1]], [target.x, target.center[1]]] if source.node.lane == target.node.lane
        finish = if lane_index(target.node.lane) > lane_index(source.node.lane)
          [target.center[0], target.y]
        else
          [target.center[0], target.bottom]
        end
        [[source.right, source.center[1]], [target.center[0], source.center[1]], finish]
      end

      def effective_style(edge)
        return :accent if @d.type == :swimlane && edge.focal
        return :revision if @d.type == :swimlane && edge.dashed
        return :neutral if @d.type == :swimlane
        focal = @d.operations.find(&:focal)
        [edge.from, edge.to].include?(focal.id) ? :accent : :neutral
      end

      def legend_rows(routes)
        rows = []
        step_entries = @d.workflow_stages.map { |item| { code: item.number.to_s, label: item.label, focal: item.focal } }
        rows << measured_row(:steps, 'STEPS', step_entries)
        if @d.type == :process
          payloads = Diagram::WORKFLOW_PAYLOADS.select do |code|
            @d.operations.any? { |item| item.input == code || item.output == code }
          end
          rows << measured_row(:payload, 'DATA TYPE', payloads.map { |code| { code: code, label: payload_label(code) } })
        end
        flow_styles = %i[neutral revision accent trigger].select { |style| routes.any? { |route| route.style == style } }
        labels = { neutral: 'Handoff', revision: 'Revision handoff', accent: @d.type == :process ? 'Focal-touching handoff' : 'Focal handoff', trigger: 'Return trigger' }
        rows << measured_row(:flow, 'FLOW', flow_styles.map { |style| { code: style, label: labels.fetch(style) } })
        rows
      end

      def measured_row(kind, label, entries)
        available = @width - 228
        lines = [[]]
        used = 0
        entries.each do |entry|
          entry_width = self.class.legend_entry_width(kind, entry)
          if entry_width > available
            @width += entry_width - available
            available = entry_width
          end
          entry = entry.merge(width: entry_width)
          if used.positive? && used + entry_width + 8 > available
            lines << []
            used = 0
          end
          lines.last << entry
          used += entry_width + 8
        end
        { kind: kind, label: label, lines: lines }
      end

      def payload_label(code)
        { 'LS' => 'List / task', 'DB' => 'Dataset', 'TB' => 'Table', 'FL' => 'File', 'WB' => 'Web' }.fetch(code)
      end

      def validate_routes!(routes, boxes, legend_top)
        routes.each do |route|
          unless route.points.each_cons(2).all? { |left, right| left[0] == right[0] || left[1] == right[1] }
            raise LayoutError, "Workflow route #{route.edge.from} -> #{route.edge.to} is not orthogonal"
          end
          boxes.reject { |box| [route.edge.from, route.edge.to].include?(box.node.id) }.each do |box|
            if route.points.each_cons(2).any? { |left, right| Geometry.blocked?(left, right, box.rect) }
              raise LayoutError, "Workflow route #{route.edge.from} -> #{route.edge.to} crosses card #{box.node.id}; split or reorder the workflow"
            end
          end
          next unless route.style == :trigger
          unless route.points[1][1] > @grid_bottom && route.points[2][1] > @grid_bottom && route.label_box[:rect][3] < legend_top
            raise LayoutError, 'Process return trigger cannot clear the workflow grid and legend'
          end
        end
        routes.each_with_index do |route, index|
          routes.first(index).each do |other|
            crossing = route.points.each_cons(2).any? do |a, b|
              other.points.each_cons(2).any? { |c, d| Geometry.crossing(a, b, c, d) || Geometry.parallel_conflict?(a, b, c, d, gap: 1) }
            end
            raise LayoutError, "Workflow routes #{other.edge.from} -> #{other.edge.to} and #{route.edge.from} -> #{route.edge.to} cross; split or reorder the workflow" if crossing
          end
        end
      end

      def workflow_label_box(edge, points, boxes)
        width = Text.grid(Text.width(edge.label.upcase, 12, font: :mono) + 16)
        candidates = points.each_cons(2).filter_map do |left, right|
          next unless left[1] == right[1]
          length = (right[0] - left[0]).abs
          next if length < width + 8
          cx = (left[0] + right[0]) / 2.0
          rect = [cx - width / 2.0, left[1] - 9, cx + width / 2.0, left[1] + 9]
          [length, rect]
        end.sort_by { |length, _| -length }
        rect = candidates.map(&:last).find do |candidate|
          boxes.reject { |box| [edge.from, edge.to].include?(box.node.id) }.none? do |box|
            Geometry.overlaps?(candidate, box.rect(4))
          end
        end
        unless rect
          raise LayoutError, "Workflow handoff #{edge.from} -> #{edge.to} has no measured label corridor; shorten its label or split the workflow"
        end
        { rect: rect, lines: [edge.label.upcase] }
      end

      def boxes_for(boxes, edge)
        [boxes.find { |box| box.node.id == edge.from }, boxes.find { |box| box.node.id == edge.to }]
      end

      def lane_index(id) = @d.workflow_lanes.index { |item| item.id == id }
      def stage_center(index) = LABEL_WIDTH + 8 + index * @stage_width + @card_width / 2

      def measured_card_width
        widths = @cards.flat_map do |card|
          title_width = Text.width(card.label, 14)
          if @d.type == :process
            lane = @d.workflow_lanes.find { |item| item.id == card.lane }
            title_width += self.class.chip_width(lane.key) + 14
          else
            title_width += 16
          end
          [title_width, card.detail && Text.width(card.detail, 12, font: :mono) + 16,
           card.tool && Text.width(card.tool, 12, font: :mono)]
        end.compact
        Text.grid([CARD_WIDTH, widths.max.to_f].max)
      end

      def measured_stage_width
        label_width = @d.workflow_stages.map { |stage| Text.width(stage.label.upcase, 12, font: :mono) + 12 }.max.to_f
        handoff_label_width = @d.workflow_handoffs.filter_map do |handoff|
          Text.width(handoff.label.upcase, 12, font: :mono) + 24 if handoff.label
        end.max.to_f
        Text.grid([STAGE_WIDTH, @card_width + 12, label_width, handoff_label_width + @card_width / 2.0].max)
      end

      def ensure_fits!(value, width, size, font, subject)
        return if Text.width(value, size, font: font) <= width
        raise LayoutError, "Workflow #{subject} does not fit its fixed card; shorten it"
      end
    end
  end
end
