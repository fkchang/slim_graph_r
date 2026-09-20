# frozen_string_literal: true
module SlimGraphR
  module Layout
    class Pyramid
      BAND_HEIGHT = 64
      MAX_WIDTH = 480.0
      APEX_WIDTH = 96.0
      LEFT = 40.0
      TOP = 24.0
      LEADER_GAP = 28.0
      LABEL_GAP = 16.0

      def initialize(diagram) = @d = diagram

      def call
        widths = boundary_widths
        bands = @d.levels.each_with_index.map { |level, index| build_band(level, index, widths) }
        leader_labels = bands.select { |band| band[:outside] }
        label_width = leader_labels.map { |band| band[:label_width] }.max || 0
        width = LEFT * 2 + MAX_WIDTH + (leader_labels.empty? ? 0 : LEADER_GAP + LABEL_GAP + label_width)
        Scene.new(boxes: [], routes: [], zones: [], lifelines: [], events: [], pyramid_bands: bands,
                  width: Text.grid(width), height: TOP * 2 + @d.levels.size * BAND_HEIGHT)
      end

      private

      def boundary_widths
        return Array.new(@d.levels.size + 1) { |index| MAX_WIDTH - (MAX_WIDTH - APEX_WIDTH) * index / @d.levels.size } if @d.mode == :hierarchy
        first = @d.levels.first.from
        values = [first] + @d.levels.map(&:to)
        values.map do |amount|
          width = amount.fdiv(first) * MAX_WIDTH
          endpoints_distinct = (LEFT + MAX_WIDTH / 2.0 - width / 2.0).to_s != (LEFT + MAX_WIDTH / 2.0 + width / 2.0).to_s
          if amount.positive? && (!width.finite? || width.zero? || !endpoints_distinct)
            raise LayoutError, 'Measured pyramid scale cannot preserve a positive boundary in SVG coordinates; use a less extreme scale'
          end
          width
        end
      end

      def build_band(level, index, widths)
        if @d.orientation == :pyramid
          visual_row = @d.levels.size - index - 1
          top_width, bottom_width = widths[index + 1], widths[index]
        else
          visual_row = index
          top_width, bottom_width = widths[index], widths[index + 1]
        end
        top = TOP + visual_row * BAND_HEIGHT
        cx = LEFT + MAX_WIDTH / 2.0
        points = [
          [cx - top_width / 2.0, top], [cx + top_width / 2.0, top],
          [cx + bottom_width / 2.0, top + BAND_HEIGHT], [cx - bottom_width / 2.0, top + BAND_HEIGHT]
        ]
        value = @d.mode == :measured ? "#{format_amount(level.from)} → #{format_amount(level.to)} #{@d.unit}" : level.detail
        full = [level.label, value].compact.join(' · ')
        outside_width = Text.width(full, 12)
        name_width = Text.width(level.label, 12)
        value_width = value ? Text.width(value, 10, font: :mono) : 0
        if value
          name_available = glyph_width(top_width, bottom_width, BAND_HEIGHT / 2.0 - 17, BAND_HEIGHT / 2.0 - 1) - 24
          value_available = glyph_width(top_width, bottom_width, BAND_HEIGHT / 2.0 - 1, BAND_HEIGHT / 2.0 + 15) - 24
          outside = name_width > name_available || value_width > value_available
        else
          available = glyph_width(top_width, bottom_width, BAND_HEIGHT / 2.0 - 10, BAND_HEIGHT / 2.0 + 6) - 24
          outside = name_width > available
        end
        if @d.mode == :hierarchy && outside
          raise LayoutError, "Hierarchy pyramid level #{level.id} text does not fit its true sloped band; shorten the label or detail"
        end
        center_face_width = top_width + (bottom_width - top_width) * 0.5
        anchor_x = cx + center_face_width / 2.0
        {
          level: level, points: points, top_width: top_width, bottom_width: bottom_width,
          y: top, center_y: top + BAND_HEIGHT / 2.0, text: full, outside: outside,
          label_width: outside_width, anchor_x: anchor_x,
          from_width: level.from.nil? ? nil : level.from.fdiv(@d.levels.first.from) * MAX_WIDTH,
          to_width: level.to.nil? ? nil : level.to.fdiv(@d.levels.first.from) * MAX_WIDTH,
          label_x: outside ? LEFT + MAX_WIDTH + LEADER_GAP + LABEL_GAP : cx
        }
      end

      def glyph_width(top_width, bottom_width, glyph_top, glyph_bottom)
        widths = [glyph_top, glyph_bottom].map do |offset|
          fraction = [[offset / BAND_HEIGHT, 0.0].max, 1.0].min
          top_width + (bottom_width - top_width) * fraction
        end
        widths.min
      end

      def format_amount(value)
        return value.to_s unless value.is_a?(Float)
        value.to_s
      end
    end

    class Medallion
      TIER_W = 172
      TIER_H = 380
      GAP = 16
      LEFT = 16
      RIGHT = 100
      ARC_H = 80
      PATH_Y = 476
      PATH_H = 56
      PATH_GAP = 16

      def initialize(diagram) = @d = diagram

      def call
        width = LEFT + @d.tiers.size * TIER_W + (@d.tiers.size - 1) * GAP + RIGHT
        cards = @d.tiers.each_with_index.map { |tier, index| card(tier, index) }
        arcs = @d.promotions.each_with_index.map { |promotion, index| arc(promotion, index, cards) }
        paths = build_paths(width)
        Scene.new(boxes: [], routes: [], zones: [], lifelines: [], events: [], medallion_cards: cards,
                  medallion_arcs: arcs, medallion_paths: paths, width: width,
                  height: @d.write_paths.empty? ? 476 : 548)
      end

      private

      def card(tier, index)
        x = LEFT + index * (TIER_W + GAP)
        if Text.width(tier.label, 14) > TIER_W - 24
          raise LayoutError, "Medallion tier #{tier.id} label does not fit its 40px header; shorten it"
        end
        fields = [[:bucket, tier.bucket], [:tool, tier.tool], [:format, tier.format], [:writer, tier.writer]]
        wrapped = fields.to_h do |key, value|
          lines = Text.wrap(value, TIER_W - 24, 11)
          raise LayoutError, "Medallion tier #{tier.id} #{key} needs more than two lines; shorten it" if lines.size > 2
          [key, lines]
        end
        examples = tier.examples.flat_map { |value| Text.wrap(value, TIER_W - 24, 11) }
        raise LayoutError, "Medallion tier #{tier.id} examples need more than two lines; shorten them" if examples.size > 2
        { tier: tier, rect: [x, ARC_H, x + TIER_W, ARC_H + TIER_H], cx: x + TIER_W / 2.0,
          header_rect: [x, ARC_H, x + TIER_W, ARC_H + 40], fields: wrapped, examples: examples }
      end

      def arc(promotion, index, cards)
        source, target = cards.fetch(index), cards.fetch(index + 1)
        style = if target[:tier].focal then :focal
                elsif target[:tier].concern then target[:tier].concern
                else :normal
                end
        { promotion: promotion, start: [source[:cx], ARC_H], finish: [target[:cx], ARC_H],
          control1: [source[:cx], 0], control2: [target[:cx], 0],
          label: promotion.label, label_x: (source[:cx] + target[:cx]) / 2.0, label_y: 50,
          style: style, dashed: target[:tier].archive }
      end

      def build_paths(width)
        count = @d.write_paths.size
        return [] if count.zero?
        card_width = count == 1 ? width - LEFT * 2 : (width - LEFT * 2 - PATH_GAP) / 2.0
        @d.write_paths.each_with_index.map do |item, index|
          x = LEFT + index * (card_width + PATH_GAP)
          tag_width = Text.grid(Text.width(item.tag, 8, font: :mono) + 12)
          title_x = x + 8 + tag_width + 16
          available = x + card_width - 12 - title_x
          if available <= 0 || Text.width(item.title, 11) > available || Text.width(item.detail, 10) > available
            raise LayoutError, "Medallion write path #{item.id} tag, title, and detail do not fit distinct lanes; shorten them"
          end
          { path: item, rect: [x, PATH_Y, x + card_width, PATH_Y + PATH_H],
            tag_width: tag_width, title_x: title_x }
        end
      end
    end
  end
end
