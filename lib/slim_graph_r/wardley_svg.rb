# frozen_string_literal: true
module SlimGraphR
  class SVG
    def draw_wardley
      left, top, width, height = @s.plot
      right, bottom = left + width, top + height
      add %(<line #{attrs(x1: left, y1: top, x2: left, y2: bottom, stroke: 'var(--sgr-muted)',
                          'stroke-width': 1, 'stroke-opacity': 0.2, 'data-sgr-wardley-axis': 'visibility')}/>)
      add %(<line #{attrs(x1: left, y1: bottom, x2: right, y2: bottom, stroke: 'var(--sgr-muted)',
                          'stroke-width': 1, 'stroke-opacity': 0.2, 'data-sgr-wardley-axis': 'evolution')}/>)
      @s.bands.drop(1).each do |band|
        add %(<line #{attrs(x1: band[:separator_x], y1: top, x2: band[:separator_x], y2: bottom,
                            stroke: 'var(--sgr-rule)', 'stroke-width': 1, 'stroke-opacity': 0.1,
                            'stroke-dasharray': '4 4', 'data-sgr-wardley-separator': 'true')}/>)
      end
      routed_lines = @s.dependencies + @s.movements
      crossings = routed_lines.combination(2).flat_map do |first, second|
        first.points.each_cons(2).flat_map do |a, b|
          second.points.each_cons(2).filter_map { |c, d| wardley_crossing(a, b, c, d) }
        end
      end.uniq
      @s.dependencies.each do |line_record|
        route_crossings = crossings.select { |point| wardley_point_on_segment?(point, line_record.points.first, line_record.points.last) }
        add %(<path #{attrs(d: wardley_path(line_record.points.first, line_record.points.last, route_crossings), fill: 'none',
                            stroke: 'var(--sgr-muted)', 'stroke-width': 0.8,
                            'data-sgr-hops': route_crossings.size,
                            'data-sgr-wardley-dependency': "#{line_record.record.from}:#{line_record.record.to}")}/>)
      end
      @s.movements.each do |movement|
        movement_crossings = crossings.select { |point| wardley_point_on_segment?(point, movement.points.first, movement.points.last) }
        add %(<path #{attrs(d: wardley_path(movement.points.first, movement.points.last, movement_crossings), fill: 'none',
                            stroke: 'var(--sgr-accent)', 'stroke-width': 1.2, 'stroke-dasharray': '5 4',
                            'marker-end': "url(##{@id}-arrow-accent)", 'data-sgr-hops': movement_crossings.size,
                            'data-sgr-wardley-movement': movement.record.id)}/>)
      end
      @s.points.each do |point|
        moving = point.component.evolving_to
        add %(<circle #{attrs(cx: point.cx, cy: point.cy, r: Layout::Wardley::DOT_RADIUS,
                              fill: moving ? 'var(--sgr-tint)' : 'var(--sgr-paper)',
                              stroke: moving ? 'var(--sgr-accent)' : 'var(--sgr-ink)', 'stroke-width': 1,
                              'data-sgr-wardley-component': point.component.id,
                              'data-sgr-wardley-evolution': point.component.evolution,
                              'data-sgr-wardley-visibility': format('%.12g', point.component.visibility))}/>)
        text(point.component.label, point.label_x, point.label_y,
             class: 'sgr-wardley-component', 'text-anchor': 'middle',
             'data-sgr-wardley-label': point.component.id,
             'data-sgr-wardley-label-lane': point.label_lane)
      end
      @s.bands.each do |band|
        text(band[:label], band[:cx], bottom + 26, class: 'sgr-wardley-band', 'text-anchor': 'middle',
             'data-sgr-wardley-band': band[:label].downcase)
      end
      stacked_axis_text(%w[VISIBLE TO THE USER], 34, top + 2, :top)
      stacked_axis_text(%w[INVISIBLE], 34, bottom - 16, :bottom)
      text(@s.caption, left, bottom + 62, class: 'sgr-wardley-caption', 'data-sgr-wardley-caption': 'true')
      line(left, bottom + 84, right, bottom + 84, 'var(--sgr-rule)')
      draw_wardley_legend(left, bottom + 112)
    end

    def wardley_description
      return @d.description if @d.description
      labels = @d.wardley_components.to_h { |item| [item.id, item.label] }
      components = @d.wardley_components.map do |item|
        band = wardley_band_name(item.evolution)
        movement = if item.evolving_to
          target = wardley_band_name(item.evolving_to)
          " and evolving to #{target}"
        else
          ''
        end
        "#{item.label} is authored in #{band} at visibility #{format('%.12g', item.visibility)}#{movement}."
      end
      dependencies = @d.wardley_dependencies.map { |item| "#{labels.fetch(item.from)} depends on #{labels.fetch(item.to)}." }
      "#{(components + dependencies).join(' ')} #{Layout::Wardley::CAPTION}"
    end

    private

    def wardley_crossing(a, b, c, d)
      denominator = (a[0] - b[0]) * (c[1] - d[1]) - (a[1] - b[1]) * (c[0] - d[0])
      return if denominator.abs < 1e-9
      t = ((a[0] - c[0]) * (c[1] - d[1]) - (a[1] - c[1]) * (c[0] - d[0])) / denominator.to_f
      u = -((a[0] - b[0]) * (a[1] - c[1]) - (a[1] - b[1]) * (a[0] - c[0])) / denominator.to_f
      return unless t.between?(0.001, 0.999) && u.between?(0.001, 0.999)
      [a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])]
    end

    def wardley_point_on_segment?(point, a, b)
      cross = (b[0] - a[0]) * (point[1] - a[1]) - (b[1] - a[1]) * (point[0] - a[0])
      cross.abs < 0.01 && point[0].between?(*[a[0], b[0]].minmax) && point[1].between?(*[a[1], b[1]].minmax)
    end

    def wardley_path(a, b, crossings)
      dx, dy = b[0] - a[0], b[1] - a[1]
      length = Math.hypot(dx, dy)
      ux, uy = dx / length, dy / length
      ordered = crossings.sort_by { |point| (point[0] - a[0]) * ux + (point[1] - a[1]) * uy }
      path = "M #{a.join(' ')}"
      ordered.each do |x, y|
        before = [x - ux * 8, y - uy * 8]
        after = [x + ux * 8, y + uy * 8]
        control = [x - uy * 6, y + ux * 6]
        path += " L #{before.join(' ')} Q #{control.join(' ')} #{after.join(' ')}"
      end
      "#{path} L #{b.join(' ')}"
    end

    def wardley_band_name(value)
      { genesis: 'Genesis', custom_built: 'Custom-built', product: 'Product', commodity: 'Commodity' }.fetch(value)
    end

    def stacked_axis_text(words, x, y, position)
      words.each_with_index do |word, index|
        text(word, x, y + index * 11, class: 'sgr-wardley-axis-copy', 'text-anchor': 'start',
             'data-sgr-wardley-axis-copy': position)
      end
    end

    def draw_wardley_legend(x, y)
      add %(<circle #{attrs(cx: x + 6, cy: y, r: Layout::Wardley::DOT_RADIUS, fill: 'var(--sgr-paper)', stroke: 'var(--sgr-ink)', 'stroke-width': 1)}/>)
      text('COMPONENT', x + 22, y + 3, class: 'sgr-wardley-legend')
      add %(<line #{attrs(x1: x + 142, y1: y, x2: x + 184, y2: y, stroke: 'var(--sgr-muted)', 'stroke-width': 0.8)}/>)
      text('DEPENDS ON', x + 196, y + 3, class: 'sgr-wardley-legend')
      add %(<circle #{attrs(cx: x + 322, cy: y, r: Layout::Wardley::DOT_RADIUS, fill: 'var(--sgr-tint)', stroke: 'var(--sgr-accent)', 'stroke-width': 1)}/>)
      add %(<line #{attrs(x1: x + 332, y1: y, x2: x + 382, y2: y, stroke: 'var(--sgr-accent)', 'stroke-width': 1.2,
                          'stroke-dasharray': '5 4', 'marker-end': "url(##{@id}-arrow-accent)")}/>)
      text('EVOLVING', x + 394, y + 3, class: 'sgr-wardley-legend')
    end
  end
end
