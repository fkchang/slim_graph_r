# frozen_string_literal: true
module SlimGraphR
  module Layout
    class Sequence
      def initialize(diagram)
        @d = diagram
        @active = Hash.new { |hash, key| hash[key] = [] }
      end

      def call
        boxes = @d.nodes.each_with_index.map do |node, index|
          Box.new(node: node, x: 64 + index * 272, y: 32, width: 208, height: 88,
                  lines: Text.wrap(node.label, 168), details: node.detail ? Text.wrap(node.detail, 168, 12) : [])
        end
        header_height = Text.grid(boxes.map { |box| box.lines.size * 20 + box.details.size * 16 + 32 }.max)
        boxes.each { |box| box.height = [88, header_height].max }
        @boxes = boxes.to_h { |box| [box.node.id, box] }
        @scene = Scene.new(boxes: boxes, routes: [], zones: [], width: boxes.last.right + 96,
                           height: 0, lifelines: [], events: [], activations: [], fragments: [])
        @cursor = boxes.first.bottom + 40
        @last_route = nil
        render_items(@d.sequence_items)
        @scene.height = @cursor + 24
        @scene.lifelines = boxes.map { |box| [box.center[0], box.bottom, @cursor] }
        @scene.width = Text.grid([@scene.width, *@scene.routes.filter_map { |r| r.label_box && r.label_box[:rect][2] + 32 }, *@scene.fragments.map { |f| f[:rect][2] + 32 }].max)
        @scene
      end

      private

      def render_items(items)
        items.each do |item|
          case item
          when Edge then render_message(item)
          when Activation then render_activation(item)
          when Fragment then render_fragment(item)
          end
        end
      end

      def actor_bounds(actor)
        cx = @boxes.fetch(actor).center[0]
        level = @active[actor].size
        return [cx, cx] if level.zero?
        left = cx - 4 + (level - 1) * 4
        [left, left + 8]
      end

      def render_message(edge)
        source = @boxes.fetch(edge.from)
        target = @boxes.fetch(edge.to)
        self_message = edge.from == edge.to
        if self_message
          lines = Text.wrap(edge.label || '', 128, 12)
          label_height = lines.size * 16 + 12
          label_width = Text.grid(lines.map { |line| Text.width(line, 12) }.max + 16)
          y = @cursor + 8
          x = actor_bounds(edge.from).last
          loop_x = x + 64
          loop_height = [48, Text.grid(label_height + 16)].max
          points = [[x, y], [loop_x, y], [loop_x, y + loop_height], [x, y + loop_height]]
          label = if edge.label && !edge.label.empty?
            top = y + (loop_height - label_height) / 2
            { rect: [loop_x + 12, top, loop_x + 12 + label_width, top + label_height], lines: lines }
          end
          @cursor = y + loop_height + 40
        else
          left, right = [source.center[0], target.center[0]].sort
          lanes = @scene.boxes.map { |box| box.center[0] }.select { |x| x.between?(left, right) }
          gaps = lanes.each_cons(2).to_a
          gap = gaps.min_by { |a, b| ((a + b) / 2.0 - (left + right) / 2.0).abs }
          lines = Text.wrap(edge.label || '', gap[1] - gap[0] - 48, 12)
          height = lines.size * 16 + 12
          width = Text.grid(lines.map { |line| Text.width(line, 12) }.max + 16)
          y = @cursor + height + 8
          moving_right = source.center[0] < target.center[0]
          x1 = actor_bounds(edge.from)[moving_right ? 1 : 0]
          x2 = actor_bounds(edge.to)[moving_right ? 0 : 1]
          points = [[x1, y], [x2, y]]
          mid = (gap[0] + gap[1]) / 2
          label = edge.label && !edge.label.empty? ? { rect: [mid - width / 2, y - height - 8, mid + width / 2, y - 8], lines: lines } : nil
          @cursor = y + 40
        end
        route = Route.new(edge: edge, points: points, label_box: label)
        @scene.routes << route
        @last_route = route
        @last_end = points.last[1]
      end

      def render_activation(item)
        previous = @last_route
        start = previous && previous.edge.to == item.actor ? previous.points.last[1] : @cursor
        level = @active[item.actor].size
        cx = @boxes.fetch(item.actor).center[0]
        bar = { actor: item.actor, depth: level, rect: [cx - 4 + level * 4, start, cx + 4 + level * 4, nil] }
        @scene.activations << bar
        @active[item.actor] << bar
        if previous && previous.edge.to == item.actor
          # A scoped activation following a call begins on that incoming arrow.
          approach = previous.points[-2][0]
          previous.points.last[0] = approach <= cx ? bar[:rect][0] : bar[:rect][2]
        end
        render_items(item.items)
        finish = @last_end ? @last_end + 12 : start + 24
        bar[:rect][3] = [finish, start + 24].max
        @active[item.actor].pop
        # Only a preceding message in the current scope can anchor a new activation.
        @last_route = nil
      end

      def participant_ids(items)
        items.flat_map do |item|
          case item
          when Edge then [item.from, item.to]
          when Activation then [item.actor] + participant_ids(item.items)
          when Fragment then item.regions.flat_map { |region| participant_ids(region.items) }
          end
        end.uniq
      end

      def render_fragment(item)
        actors = item.regions.flat_map { |region| participant_ids(region.items) }.uniq
        indices = actors.map { |id| @scene.boxes.index(@boxes.fetch(id)) }.sort
        unless indices == (indices.min..indices.max).to_a
          raise LayoutError, 'Frame participants must be adjacent; reorder participant declarations or split the sequence'
        end
        first_x, last_x = actors.map { |id| @boxes.fetch(id).center[0] }.minmax
        top = @cursor
        start_index = @scene.routes.size
        frame = { operator: item.operator, actors: actors, rect: [first_x - 64, top, last_x + 64, nil], regions: [] }
        @scene.fragments << frame
        @last_route = nil
        item.regions.each_with_index do |region, index|
          @cursor += index.zero? ? 32 : 24
          guard_lines = Text.wrap("[#{region.guard}]", 224, 12, font: :mono)
          guard_y = @cursor + 12
          frame[:regions] << { guard: region.guard, lines: guard_lines, x: first_x + 20, y: guard_y, divider: index.zero? ? nil : @cursor - 24 }
          frame[:rect][2] = [frame[:rect][2], first_x + 20 + guard_lines.map { |line| Text.width(line, 12, font: :mono) }.max + 16].max
          @cursor = guard_y + (guard_lines.size - 1) * 16 + 24
          @last_route = nil
          render_items(region.items)
          @cursor = [@cursor, @scene.routes.last.points.last[1] + 24].max
        end
        frame[:rect][3] = @cursor
        contained = @scene.routes[start_index..]
        frame[:rect][2] = [frame[:rect][2], *contained.flat_map { |r| [r.points.map(&:first).max + 16, r.label_box && r.label_box[:rect][2] + 16] }.compact].max
        frame[:rect] = frame[:rect].map { |value| Text.grid(value) }
        @cursor += 32
        @last_route = nil
      end
    end
  end
end
