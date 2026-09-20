# frozen_string_literal: true
module SlimGraphR
  module Layout
    class Tree
      MARGIN = 40
      NODE_GAP = 32
      TIER_GAP = 80
      MIN_WIDTH = 120
      MAX_WIDTH = 180
      MAX_SCENE = 1_140

      def initialize(diagram) = @d = diagram

      def call
        @boxes = @d.tree_nodes.to_h { |node| [node.id, measure(node)] }
        @children = @d.tree_nodes.group_by(&:parent_id)
        @root = @d.tree_nodes.find { |node| node.parent_id.nil? }
        @span_cache = {}
        @d.direction == :down ? place_down : place_right
        width = @boxes.values.map(&:right).max + MARGIN
        # Include the wrap helper's separator allowance, within its existing 720px heading budget.
        title_width = Text.grid([Text.width(@d.title + ' ', 30, font: @d.style_profile.heading_font), 720].min + MARGIN * 2)
        if title_width > width
          offset = (title_width - width) / 2.0
          @boxes.each_value { |box| box.x += offset }
          width = title_width
        end
        height = @boxes.values.map(&:bottom).max + MARGIN
        if width > MAX_SCENE || height > MAX_SCENE
          raise LayoutError, 'Tree hierarchy exceeds the bounded 1140px scene; shorten labels or split the hierarchy'
        end
        Scene.new(
          boxes: @d.tree_nodes.map { |node| @boxes.fetch(node.id) }, routes: [], zones: [], lifelines: [], events: [],
          width: width, height: height, tree_connectors: connectors
        )
      end

      private

      def measure(node)
        needed = [Text.width(node.label, 12) + 28, node.detail ? Text.width(node.detail, 9, font: :mono) + 28 : 0].max
        if needed > MAX_WIDTH
          raise LayoutError, "Tree node #{node.id} text does not fit the 180px bounded box; shorten its label or detail"
        end
        width = needed <= MIN_WIDTH ? MIN_WIDTH : MAX_WIDTH
        Box.new(node: node, width: width, height: node.detail ? 52 : 40, lines: [node.label], details: node.detail ? [node.detail] : [], shape: :tree)
      end

      def children(node) = @children.fetch(node.id, [])

      def subtree_span(node, axis)
        key = [node.id, axis]
        @span_cache[key] ||= begin
          box = @boxes.fetch(node.id)
          own = axis == :horizontal ? box.width : box.height
          descendants = children(node)
          child_span = descendants.sum { |child| subtree_span(child, axis) } + [descendants.size - 1, 0].max * NODE_GAP
          [own, child_span].max
        end
      end

      def place_down
        tier_heights = @d.tree_nodes.group_by(&:depth).transform_values { |items| items.map { |item| @boxes.fetch(item.id).height }.max }
        tier_y = {}
        cursor = 24
        tier_heights.sort.each do |depth, height|
          tier_y[depth] = cursor
          cursor += height + TIER_GAP
        end
        place_down_subtree(@root, MARGIN, tier_y)
      end

      def place_down_subtree(node, left, tier_y)
        span = subtree_span(node, :horizontal)
        box = @boxes.fetch(node.id)
        box.x = Text.grid(left + (span - box.width) / 2.0)
        box.y = tier_y.fetch(node.depth)
        cursor = left
        children(node).each do |child|
          place_down_subtree(child, cursor, tier_y)
          cursor += subtree_span(child, :horizontal) + NODE_GAP
        end
      end

      def place_right
        tier_widths = @d.tree_nodes.group_by(&:depth).transform_values { |items| items.map { |item| @boxes.fetch(item.id).width }.max }
        tier_x = {}
        cursor = MARGIN
        tier_widths.sort.each do |depth, width|
          tier_x[depth] = cursor
          cursor += width + TIER_GAP
        end
        place_right_subtree(@root, 24, tier_x)
      end

      def place_right_subtree(node, top, tier_x)
        span = subtree_span(node, :vertical)
        box = @boxes.fetch(node.id)
        box.x = tier_x.fetch(node.depth)
        box.y = Text.grid(top + (span - box.height) / 2.0)
        cursor = top
        children(node).each do |child|
          place_right_subtree(child, cursor, tier_x)
          cursor += subtree_span(child, :vertical) + NODE_GAP
        end
      end

      def connectors
        @d.tree_nodes.filter_map do |parent|
          descendants = children(parent)
          next if descendants.empty?
          parent_box = @boxes.fetch(parent.id)
          child_boxes = descendants.map { |child| @boxes.fetch(child.id) }
          @d.direction == :down ? down_connector(parent_box, child_boxes) : right_connector(parent_box, child_boxes)
        end
      end

      def down_connector(parent, child_boxes)
        start = [parent.center[0], parent.bottom]
        entries = child_boxes.map { |box| [box.center[0], box.y] }
        bus_y = Text.grid((parent.bottom + child_boxes.map(&:y).min) / 2.0)
        {
          parent_id: parent.node.id, stem: [start, [start[0], bus_y]],
          bus: [[entries.map(&:first).min, bus_y], [entries.map(&:first).max, bus_y]],
          drops: child_boxes.map { |box| { child_id: box.node.id, points: [[box.center[0], bus_y], [box.center[0], box.y]] } }
        }
      end

      def right_connector(parent, child_boxes)
        start = [parent.right, parent.center[1]]
        entries = child_boxes.map { |box| [box.x, box.center[1]] }
        bus_x = Text.grid((parent.right + child_boxes.map(&:x).min) / 2.0)
        {
          parent_id: parent.node.id, stem: [start, [bus_x, start[1]]],
          bus: [[bus_x, entries.map(&:last).min], [bus_x, entries.map(&:last).max]],
          drops: child_boxes.map { |box| { child_id: box.node.id, points: [[bus_x, box.center[1]], [box.x, box.center[1]]] } }
        }
      end
    end

    class Nested
      INSET_X = 28
      INSET_Y = 34
      INNER_WIDTH = 240
      INNER_HEIGHT = 112
      MAX_OUTER_WIDTH = 880

      def initialize(diagram) = @d = diagram

      def call
        count = @d.containment_scopes.size
        base_width = @d.containment_scopes.each_with_index.map do |item, index|
          rendered = item.label.upcase
          Text.width(rendered, 8, font: :mono) + rendered.length * 1.12 + 40 - (count - index - 1) * INSET_X * 2
        end.push(INNER_WIDTH).max
        inner_width = Text.grid(base_width)
        outer_width = inner_width + (count - 1) * INSET_X * 2
        if outer_width > MAX_OUTER_WIDTH
          raise LayoutError, 'Nested-containment scope labels exceed the bounded 880px outer ring; shorten them'
        end
        outer_height = INNER_HEIGHT + (count - 1) * INSET_Y * 2
        scopes = @d.containment_scopes.each_with_index.map do |item, index|
          x = 40 + index * INSET_X
          y = 24 + index * INSET_Y
          width = outer_width - index * INSET_X * 2
          height = outer_height - index * INSET_Y * 2
          label = item.label.upcase
          label_width = Text.grid(Text.width(label, 8, font: :mono) + label.length * 1.12 + 16)
          if label_width > width - 24
            raise LayoutError, "Nested-containment label #{item.label.inspect} does not fit its regular ring; shorten it"
          end
          {
            scope: item, label: label, focal: index == count - 1,
            rect: [x, y, x + width, y + height], label_rect: [x + 12, y - 7, x + 12 + label_width, y + 9],
            inset_x: INSET_X, inset_y: INSET_Y, strength: index + 1
          }
        end
        Scene.new(
          boxes: [], routes: [], zones: [], lifelines: [], events: [], nested_scopes: scopes,
          width: outer_width + 80, height: outer_height + 48
        )
      end
    end

    class Layers
      STACK_X = 152
      TOP = 24
      ROW_HEIGHT = 64
      MIN_WIDTH = 800
      MAX_WIDTH = 880

      def initialize(diagram) = @d = diagram

      def call
        index_width = Text.grid(@d.layers.map do |item|
          rendered = item.index.upcase
          Text.width(rendered, 9, font: :mono) + rendered.length * 0.72
        end.max + 8)
        name_width = Text.grid(@d.layers.map { |item| Text.width(item.label, 15) }.max + 8)
        detail_width = Text.grid(@d.layers.map { |item| item.detail ? Text.width(item.detail, 10, font: :mono) : 0 }.max + 8)
        natural_width = 24 + index_width + 28 + name_width + 48 + detail_width + 24
        stack_width = Text.grid([MIN_WIDTH, natural_width].max)
        if stack_width > MAX_WIDTH
          raise LayoutError, 'Layer-stack columns exceed the bounded 880px stack; shorten an index, name, or detail'
        end
        axis_label = @d.axis.upcase
        if Text.width(axis_label, 9, font: :mono) + axis_label.length * 0.72 > @d.layers.size * ROW_HEIGHT - 56
          raise LayoutError, 'Layer-stack axis label does not fit outside the stack; shorten it'
        end
        rows = @d.layers.each_with_index.map do |item, row|
          y = TOP + row * ROW_HEIGHT
          {
            layer: item, rect: [STACK_X, y, STACK_X + stack_width, y + ROW_HEIGHT],
            index_x: STACK_X + 24, name_x: STACK_X + 24 + index_width + 28,
            detail_x: STACK_X + stack_width - 24, row: row
          }
        end
        bottom = TOP + rows.size * ROW_HEIGHT
        indicator = {
          label: axis_label, direction: @d.indicator, x: 72,
          top: TOP + 20, bottom: bottom - 20, center_y: (TOP + bottom) / 2.0
        }
        Scene.new(
          boxes: [], routes: [], zones: [], lifelines: [], events: [], layer_rows: rows,
          direction_indicator: indicator, width: STACK_X + stack_width + 40, height: bottom + 32
        )
      end
    end
  end
end
