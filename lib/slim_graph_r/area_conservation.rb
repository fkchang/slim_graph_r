# frozen_string_literal: true

module SlimGraphR
  module AreaConservation
    Item = Struct.new(:id, :label, :value, :focal, keyword_init: true)
    Stage = Struct.new(:id, :label, keyword_init: true)
    Node = Struct.new(:id, :stage, :label, :value, keyword_init: true)
    Flow = Struct.new(:from, :to, :value, :focal, keyword_init: true)
    Cell = Struct.new(:item, :x, :y, :width, :height, :share, :external, keyword_init: true)
    NodeBox = Struct.new(:node, :x, :y, :width, :height, :incoming, :outgoing, keyword_init: true)
    Ribbon = Struct.new(:flow, :source, :target, :thickness, :source_start, :source_end,
                        :target_start, :target_end, keyword_init: true)

    class TreemapLayout
      PLOT_X = BigDecimal('40')
      PLOT_Y = BigDecimal('112')
      PLOT_WIDTH = BigDecimal('920')
      PLOT_HEIGHT = BigDecimal('440')
      attr_reader :cells, :plot_x, :plot_y, :plot_width, :plot_height

      def initialize(chart)
        @chart = chart
        @plot_x, @plot_y, @plot_width, @plot_height = PLOT_X, PLOT_Y, PLOT_WIDTH, PLOT_HEIGHT
        validate_text!
        @cells = squarify(chart.items.select { |item| item.value.positive? })
        @cells.each(&:freeze)
        @cells.freeze
        freeze
      end

      private

      def validate_text!
        raise LayoutError, 'Treemap title does not fit; shorten the title, enlarge the canvas, or split the chart' if Text.width(@chart.title, 30, font: @chart.style_profile.heading_font) > 920
        @chart.items.each do |item|
          legend = "#{item.label} · #{Quantitative::Value.format(item.value, @chart.precision)} #{@chart.unit} · 100.000000% · NO CELL"
          if Text.width(legend, 12, font: :mono) > 896
            raise LayoutError, 'Treemap legend does not fit; shorten an item label or unit, enlarge the canvas, or split the chart'
          end
        end
        if @chart.source_note && Text.width(@chart.source_note, 12, font: :mono) > 920
          raise LayoutError, 'Treemap source note does not fit; shorten it, enlarge the canvas, or split the chart'
        end
      end

      def squarify(items)
        total = items.sum(BigDecimal('0'), &:value)
        weighted = items.sort_by { |item| [-item.value, item.id] }.map do |item|
          [item, item.value * plot_width * plot_height / total]
        end
        result = []
        x, y, width, height = plot_x, plot_y, plot_width, plot_height
        row = []
        until weighted.empty?
          candidate = weighted.first
          side = [width, height].min
          if row.empty? || worst(row + [candidate], side) <= worst(row, side)
            row << weighted.shift
          else
            x, y, width, height = place_row(row, x, y, width, height, result, total)
            row = []
          end
        end
        place_row(row, x, y, width, height, result, total) unless row.empty?
        result
      end

      def worst(row, side)
        return BigDecimal('Infinity') if row.empty? || side.zero?
        areas = row.map(&:last)
        sum = areas.sum(BigDecimal('0'))
        [side * side * areas.max / (sum * sum), (sum * sum) / (side * side * areas.min)].max
      end

      def place_row(row, x, y, width, height, result, total)
        area = row.sum(BigDecimal('0')) { |entry| entry.last }
        horizontal = width >= height
        thickness = horizontal ? area / height : area / width
        cursor = horizontal ? y : x
        row.each_with_index do |(item, item_area), index|
          length = index == row.length - 1 ? (horizontal ? y + height - cursor : x + width - cursor) : item_area / thickness
          cell_x, cell_y = horizontal ? [x, cursor] : [cursor, y]
          cell_width, cell_height = horizontal ? [thickness, length] : [length, thickness]
          external = cell_width < 116 || cell_height < 54
          result << Cell.new(item: item, x: cell_x, y: cell_y, width: cell_width, height: cell_height,
                             share: item.value / total, external: external)
          cursor += length
        end
        horizontal ? [x + thickness, y, width - thickness, height] : [x, y + thickness, width, height - thickness]
      end
    end

    class SankeyLayout
      DISPLAY_SCALE = BigDecimal('1.143')
      BAR_WIDTH = BigDecimal('12')
      TOTAL_HEIGHT = BigDecimal('300')
      GAP = BigDecimal('40')
      XS = [BigDecimal('180'), BigDecimal('500'), BigDecimal('820')].freeze
      attr_reader :node_boxes, :ribbons, :px_per_unit, :width, :height

      def initialize(chart)
        @chart = chart
        @width = 1000
        @px_per_unit = TOTAL_HEIGHT / chart.stage_total
        smallest = chart.flows.map(&:value).min * px_per_unit * DISPLAY_SCALE
        if smallest < 1
          raise LayoutError, 'Smallest Sankey ribbon is below one device pixel; aggregate it upstream under an authored name or split the chart'
        end
        validate_text!
        build_boxes
        build_ribbons
        @height = (@node_boxes.map { |box| box.y + box.height }.max + 104).ceil
        @node_boxes.each(&:freeze); @node_boxes.freeze
        @ribbons.each(&:freeze); @ribbons.freeze
        freeze
      end

      private

      def validate_text!
        raise LayoutError, 'Sankey title does not fit; shorten the title, enlarge the canvas, or split the chart' if Text.width(@chart.title, 30, font: @chart.style_profile.heading_font) > 920
        @chart.nodes.each do |node|
          limit = node.stage == @chart.stages[1].id ? 220 : 140
          if Text.width(node.label, 14) > limit || Text.width("#{Quantitative::Value.format(node.value, @chart.precision)} #{@chart.unit}", 12, font: :mono) > limit
            raise LayoutError, 'Sankey node label does not fit; shorten a label or unit, enlarge the canvas, or split the chart'
          end
        end
        if @chart.source_note && Text.width(@chart.source_note, 12, font: :mono) > 920
          raise LayoutError, 'Sankey source note does not fit; shorten it, enlarge the canvas, or split the chart'
        end
      end

      def build_boxes
        @node_boxes = []
        @chart.stages.each_with_index do |stage, stage_index|
          nodes = ordered_nodes(stage.id, stage_index)
          stack_height = nodes.sum(BigDecimal('0')) { |node| node.value * px_per_unit } + GAP * (nodes.length - 1)
          cursor = BigDecimal('164')
          nodes.each do |node|
            incoming = @chart.flows.select { |flow| flow.to == node.id }.sum(BigDecimal('0'), &:value)
            outgoing = @chart.flows.select { |flow| flow.from == node.id }.sum(BigDecimal('0'), &:value)
            @node_boxes << NodeBox.new(node: node, x: XS[stage_index], y: cursor, width: BAR_WIDTH,
                                      height: node.value * px_per_unit, incoming: incoming, outgoing: outgoing)
            cursor += node.value * px_per_unit + GAP
          end
        end
      end

      # Barycentric passes give deterministic crossing reduction while preserving values and author IDs.
      def ordered_nodes(stage_id, stage_index)
        nodes = @chart.nodes.select { |node| node.stage == stage_id }
        return nodes if stage_index.zero?
        previous = @node_boxes.each_with_index.to_h { |box, index| [box.node.id, index] }
        nodes.sort_by do |node|
          incoming = @chart.flows.select { |flow| flow.to == node.id }
          score = incoming.empty? ? 1_000_000 : incoming.sum { |flow| previous.fetch(flow.from, 0) } / incoming.length.to_f
          [score, node.id]
        end
      end

      def build_ribbons
        boxes = @node_boxes.to_h { |box| [box.node.id, box] }
        source_offsets = Hash.new(BigDecimal('0'))
        target_offsets = Hash.new(BigDecimal('0'))
        @ribbons = @chart.flows.sort_by do |flow|
          [boxes.fetch(flow.from).y, boxes.fetch(flow.to).y, flow.from, flow.to]
        end.map do |flow|
          source, target = boxes.fetch(flow.from), boxes.fetch(flow.to)
          thickness = flow.value * px_per_unit
          source_start = source_offsets[flow.from]
          target_start = target_offsets[flow.to]
          source_offsets[flow.from] += thickness
          target_offsets[flow.to] += thickness
          Ribbon.new(flow: flow, source: source, target: target, thickness: thickness,
                     source_start: source_start, source_end: source_offsets[flow.from],
                     target_start: target_start, target_end: target_offsets[flow.to])
        end
      end
    end

    class Chart
      attr_reader :type, :title, :description, :style, :theme, :unit, :source_note,
                  :precision, :notation, :items, :stages, :nodes, :flows, :balance

      def initialize(type, title: 'Diagram', description: nil, unit: nil, style: :editorial,
                     theme: :light, source_note: nil, precision: 3, notation: :plain,
                     balance: :strict, &block)
        @type = type.to_s.to_sym
        raise Error, 'Area/conservation type must be treemap or sankey' unless %i[treemap sankey].include?(@type)
        @title = Quantitative::Value.text(title, 'Title')
        @description = description.nil? ? nil : Quantitative::Value.text(description, 'Description')
        @unit = unit.nil? ? nil : Quantitative::Value.text(unit, 'Unit')
        @source_note = source_note.nil? ? nil : Quantitative::Value.text(source_note, 'Source note')
        raise Error, 'precision must be an Integer from 0 through 6' unless precision.is_a?(Integer) && precision.between?(0, 6)
        @precision = precision
        @notation = notation.to_s.to_sym
        raise Error, 'notation must be :plain' unless @notation == :plain
        @style = Style.fetch(style).name
        @theme = theme.to_s.to_sym
        raise Error, 'Theme must be :light, :dark, or :auto' unless %i[light dark auto].include?(@theme)
        @balance = balance.to_s.to_sym
        raise Error, 'Sankey balance must be :strict' if type == :sankey && @balance != :strict
        @items, @stages, @nodes, @flows = [], [], [], []
        instance_eval(&block) if block
        validate!
        [@items, @stages, @nodes, @flows].each { |list| list.each(&:freeze); list.freeze }
        freeze
      end

      def item(id, label, value, focal: false)
        raise Error, 'item is available only for treemaps' unless type == :treemap
        @items << Item.new(id: Quantitative::Value.id(id, 'Item ID'), label: Quantitative::Value.text(label, 'Item label'),
                          value: Quantitative::Value.number(value, 'Item value'), focal: Quantitative::Value.boolean(focal, 'focal'))
      end

      def stage(id, label)
        raise Error, 'stage is available only for Sankey diagrams' unless type == :sankey
        @stages << Stage.new(id: Quantitative::Value.id(id, 'Stage ID'), label: Quantitative::Value.text(label, 'Stage label'))
      end

      def node(id, stage:, label:, value:)
        raise Error, 'node is available only for Sankey diagrams' unless type == :sankey
        @nodes << Node.new(id: Quantitative::Value.id(id, 'Node ID'), stage: Quantitative::Value.id(stage, 'Node stage'),
                          label: Quantitative::Value.text(label, 'Node label'), value: Quantitative::Value.number(value, 'Node value'))
      end

      def flow(from, to, value, focal: false)
        raise Error, 'flow is available only for Sankey diagrams' unless type == :sankey
        @flows << Flow.new(from: Quantitative::Value.id(from, 'Flow source'), to: Quantitative::Value.id(to, 'Flow target'),
                          value: Quantitative::Value.number(value, 'Flow value'), focal: Quantitative::Value.boolean(focal, 'Flow focal'))
      end

      def style_profile = Style.fetch(style)
      def layout = type == :treemap ? TreemapLayout.new(self) : SankeyLayout.new(self)
      def to_svg(id: nil) = AreaConservationSVG.new(self, id: id).render
      def to_html = "<!doctype html><html><head><meta charset=\"utf-8\"><title>#{CGI.escapeHTML(title)}</title></head><body style=\"margin:0\">#{to_svg}</body></html>"

      def with(style: @style, theme: @theme, **extra)
        raise Error, 'Area and conservation charts do not accept extra overrides' unless extra.empty?
        copy = dup
        copy.instance_variable_set(:@style, Style.fetch(style).name)
        mode = theme.to_s.to_sym
        raise Error, 'Theme must be :light, :dark, or :auto' unless %i[light dark auto].include?(mode)
        copy.instance_variable_set(:@theme, mode)
        copy.freeze
      end

      def stage_total = nodes.select { |node| node.stage == stages.first.id }.sum(BigDecimal('0'), &:value)

      def accessible_description
        return description if description
        source = source_note ? " Source: #{source_note}." : ''
        if type == :treemap
          data = items.map do |item|
            share = item.value.zero? ? '0' : Quantitative::Value.format(item.value / items.sum(BigDecimal('0'), &:value) * 100, precision)
            "#{item.label}: #{display(item.value)}; #{share}%#{item.value.zero? ? ' (zero; no cell)' : ''}#{item.focal ? ' (focal border)' : ''}"
          end.join('; ')
          "Treemap. Rectangle area equals value divided by the positive total. #{data}.#{source}"
        else
          totals = stages.map { |stage| nodes.select { |node| node.stage == stage.id }.sum(BigDecimal('0'), &:value) }
          node_text = nodes.map { |node| "#{node.label}: #{display(node.value)}" }.join('; ')
          focal = flows.select(&:focal)
          focal_text = focal.empty? ? '' : " Focal flow#{focal.size == 1 ? '' : 's'}: #{focal.map { |flow| "#{flow.from} to #{flow.to}, #{display(flow.value)}" }.join('; ')}."
          "Sankey chart. Ribbon thickness and node height use one linear scale; strict conservation verified; stage totals #{display(totals.first)}. #{node_text}.#{focal_text}#{source}"
        end
      end

      def ==(other) = other.class == self.class && state == other.send(:state)
      alias eql? ==

      protected

      def state = [type, title, description, style, theme, unit, source_note, precision, notation, items, stages, nodes, flows, balance]

      private

      def display(value) = "#{Quantitative::Value.format(value, precision)} #{unit}"

      def validate!
        raise Error, "#{type == :treemap ? 'Treemaps' : 'Sankey diagrams'} require a unit" unless unit
        type == :treemap ? validate_treemap! : validate_sankey!
      end

      def validate_treemap!
        raise Error, 'Treemaps require 2–12 items' unless items.size.between?(2, 12)
        unique!(items, 'Item')
        raise Error, 'Treemap values must be nonnegative' if items.any? { |item| item.value.negative? }
        raise Error, 'Treemaps require at least one positive value' unless items.any? { |item| item.value.positive? }
        raise Error, 'A treemap allows at most one focal item' if items.count(&:focal) > 1
        raise Error, 'A focal treemap item must be positive because zero has no cell or border' if items.any? { |item| item.focal && item.value.zero? }
      end

      def validate_sankey!
        raise Error, 'Sankey diagrams require exactly three declared stages' unless stages.size == 3
        unique!(stages, 'Stage')
        raise Error, 'Sankey diagrams require 3–10 nodes' unless nodes.size.between?(3, 10)
        unique!(nodes, 'Node')
        raise Error, 'Sankey node values must be strictly positive' unless nodes.all? { |node| node.value.positive? }
        raise Error, 'Every Sankey stage must contain a node' unless stages.all? { |stage| nodes.any? { |node| node.stage == stage.id } }
        stage_ids = stages.map(&:id)
        raise Error, 'Sankey node names an unknown stage' unless nodes.all? { |node| stage_ids.include?(node.stage) }
        raise Error, 'Sankey diagrams require 2–16 strictly positive flows' unless flows.size.between?(2, 16) && flows.all? { |flow| flow.value.positive? }
        lookup = nodes.to_h { |node| [node.id, node] }
        flows.each do |flow|
          raise Error, 'Sankey flow names an unknown node' unless lookup[flow.from] && lookup[flow.to]
          from_index = stage_ids.index(lookup.fetch(flow.from).stage)
          to_index = stage_ids.index(lookup.fetch(flow.to).stage)
          raise Error, 'Sankey flows must connect adjacent stages left to right' unless to_index == from_index + 1
        end
        nodes.each_with_index do |node, index|
          incoming = flows.select { |flow| flow.to == node.id }.sum(BigDecimal('0'), &:value)
          outgoing = flows.select { |flow| flow.from == node.id }.sum(BigDecimal('0'), &:value)
          stage_index = stage_ids.index(node.stage)
          raise Error, "Sankey node #{node.id} incoming total must equal its declared value" if stage_index.positive? && incoming != node.value
          raise Error, "Sankey node #{node.id} outgoing total must equal its declared value" if stage_index < 2 && outgoing != node.value
        end
        totals = stage_ids.map { |id| nodes.select { |node| node.stage == id }.sum(BigDecimal('0'), &:value) }
        raise Error, 'Sankey stage totals must be exactly equal' unless totals.all? { |total| total == totals.first }
        raise Error, 'Sankey requires a genuine split or merge' unless nodes.any? { |node| flows.count { |flow| flow.from == node.id } > 1 || flows.count { |flow| flow.to == node.id } > 1 }
        raise Error, 'A Sankey allows at most two focal flows' if flows.count(&:focal) > 2
      end

      def unique!(records, context)
        ids = records.map { |record| record.id.unicode_normalize(:nfc) }
        labels = records.map { |record| record.label.unicode_normalize(:nfc) }
        raise Error, "#{context} IDs must be unique" unless ids.uniq.size == ids.size
        raise Error, "#{context} labels must be unique" unless labels.uniq.size == labels.size
      end
    end
  end
end
