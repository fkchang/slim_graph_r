# frozen_string_literal: true
module SlimGraphR
  class SVG
    def draw_quadrant
      left, top, width, height = @s.plot
      right, bottom = left + width, top + height
      rect(left, top, width, height, fill: 'none', stroke: 'var(--sgr-rule)', 'stroke-width': 1,
           'data-sgr-quadrant-boundary': 'true')
      line(left, @s.center_y, right, @s.center_y, 'var(--sgr-rule)')
      line(@s.center_x, top, @s.center_x, bottom, 'var(--sgr-rule)')
      [[left + 18, @s.center_y, left, @s.center_y], [right - 18, @s.center_y, right, @s.center_y],
       [@s.center_x, top + 18, @s.center_x, top], [@s.center_x, bottom - 18, @s.center_x, bottom]].each do |x1, y1, x2, y2|
        add %(<line #{attrs(x1: x1, y1: y1, x2: x2, y2: y2, stroke: 'var(--sgr-muted)',
                            'stroke-width': 1, 'marker-end': "url(##{@id}-arrow-sm)")}/>)
      end
      @s.axis_labels.each do |label|
        text(label[:text], label[:x], label[:y], class: 'sgr-quadrant-axis', 'text-anchor': label[:anchor],
             'data-sgr-quadrant-axis': label[:side])
      end
      @s.regions.each do |region|
        text(region[:record].label, region[:x], region[:y], class: 'sgr-quadrant-region', 'text-anchor': region[:anchor],
             'data-sgr-quadrant-region': region[:record].position)
      end
      @s.points.each do |point|
        item = point.item
        add %(<circle #{attrs(cx: point.cx, cy: point.cy, r: Layout::Quadrant::DOT_RADIUS,
                              fill: item.focal ? 'var(--sgr-accent)' : 'var(--sgr-ink)',
                              stroke: item.focal ? 'var(--sgr-accent)' : 'var(--sgr-paper)', 'stroke-width': 1,
                              'data-sgr-quadrant-point': item.id,
                              'data-sgr-quadrant-x': format('%.12g', item.x),
                              'data-sgr-quadrant-y': format('%.12g', item.y),
                              'data-sgr-quadrant-focal': item.focal ? 'true' : nil)}/>)
        text(item.label, point.label_x, point.label_y,
             class: "sgr-quadrant-item#{item.focal ? ' sgr-quadrant-focal' : ''}",
             'text-anchor': point.label_anchor, 'data-sgr-quadrant-label': item.id)
      end
      text(@s.caption, @s.center_x, 602, class: 'sgr-quadrant-caption', 'text-anchor': 'middle',
           'data-sgr-quadrant-caption': 'true')
    end

    def quadrant_description
      return @d.description if @d.description
      statements = @d.items.map do |item|
        horizontal = item.x.negative? ? @d.horizontal_axis_record.low : @d.horizontal_axis_record.high
        vertical = item.y.negative? ? @d.vertical_axis_record.low : @d.vertical_axis_record.high
        "#{item.label} is authored toward #{horizontal} and #{vertical}#{item.focal ? '; selected as the focal discussion point' : ''}."
      end
      regions = @d.quadrant_regions.map { |region| "#{region.position.to_s.tr('_', ' ')}: #{region.label}" }
      region_text = regions.empty? ? '' : " Authored region labels: #{regions.join('; ')}."
      "#{statements.join(' ')}#{region_text} Positions are qualitative author judgments, not calculated scores. The focal point, when present, is author-selected and does not imply a recommendation."
    end
  end
end
