# frozen_string_literal: true

module SlimGraphR
  class RadialSVG
    DISPLAY_SCALE = 1.143
    RADIUS = 160
    CENTER_Y = 278
    HEIGHT = 620
    RING_FRACTIONS = [1, 2, 3, 4, 5].map { |n| BigDecimal(n.to_s) / 5 }.freeze
    DASHES = ['', '6 4', '2 4', '10 4 2 4', '1 3'].freeze

    def initialize(chart, id: nil)
      @chart = chart
      @id = id || "sgr-#{SecureRandom.hex(6)}"
      raise Error, 'SVG ID must start with a letter and contain only letters, digits, hyphens, underscores' unless @id.match?(/\A[a-zA-Z][a-zA-Z0-9_-]*\z/)
    end

    def render
      measure!
      palette = @chart.style_profile.public_send(@chart.theme == :dark ? :dark : :light)
      @palette = palette
      display_width = (@width * DISPLAY_SCALE).ceil
      display_height = (HEIGHT * DISPLAY_SCALE).ceil
      body = @chart.type == :polar ? draw_polar : draw_radar
      root_flag = @chart.type == :polar ? 'data-polar-chart="true"' : 'data-radar-chart="true"'
      <<~SVG.gsub(/\n\s*/, '')
        <svg xmlns="http://www.w3.org/2000/svg" id="#{@id}" class="sgr-diagram" #{root_flag} data-sgr-theme="#{@chart.theme}" data-sgr-style="#{@chart.style}" role="img" aria-labelledby="#{@id}-title #{@id}-desc" viewBox="0 0 #{@width} #{HEIGHT}" width="#{display_width}" height="#{display_height}" style="display:block;margin:0 auto;width:100%;height:auto;min-width:#{display_width}px" data-sgr-display-scale="#{DISPLAY_SCALE}" data-domain-min="0.0" data-domain-max="#{canonical(@chart.scale_domain.max)}" data-mapping="linear-radius" data-radius="#{RADIUS}.0" data-notation="plain" data-precision="#{@chart.precision}">
          <title id="#{@id}-title">#{esc(@chart.title)}</title><desc id="#{@id}-desc">#{esc(@chart.accessible_description)}</desc>
          <rect data-#{@chart.type}-background="true" x="0" y="0" width="#{@width}" height="#{HEIGHT}" fill="#{palette[:paper]}"/>
          <text x="40" y="48" fill="#{palette[:ink]}" font-family="#{esc(@chart.style_profile.heading_family)}" font-size="30" font-weight="#{@chart.style_profile.heading_weight}">#{esc(@chart.title)}</text>
          <line data-#{@chart.type}-rule="title" x1="40" y1="88" x2="#{@width - 40}" y2="88" stroke="#{palette[:rule]}" stroke-width="1"/>
          #{body}
          <text data-#{@chart.type}-caption="true" x="40" y="558" fill="#{palette[:muted]}" font-family="'Geist Mono',ui-monospace,monospace" font-size="12">#{esc(caption)}</text>
          #{@chart.source_note ? %(<text data-source-note="true" x="40" y="584" fill="#{palette[:muted]}" font-family="'Geist Mono',ui-monospace,monospace" font-size="12">#{esc(@chart.source_note)}</text>) : ''}
        </svg>
      SVG
    end

    private

    def measure!
      @width = if @chart.type == :radar
        legend = @chart.entities.sum { |item| Text.width(item.label, 12, font: :mono) + 72 }
        [1000, Text.grid(legend + 80)].max
      else
        1000
      end
      raise LayoutError, 'Chart title does not fit; shorten the title or split the chart' if Text.width(@chart.title, 30, font: @chart.style_profile.heading_font) > @width - 80
      if @chart.source_note && Text.width(@chart.source_note, 12, font: :mono) > @width - 80
        raise LayoutError, 'Source note does not fit; shorten the source note or split the chart'
      end
      raise LayoutError, 'Quantitative caption does not fit; shorten the unit or reduce precision' if Text.width(caption, 12, font: :mono) > @width - 80
      labels = @chart.type == :polar ? @chart.categories.map(&:label) : @chart.criteria.map(&:label)
      if labels.any? { |label| Text.width(label, 14) > 250 }
        remedy = @chart.type == :radar ? 'use a comparison table or small multiples' : 'shorten a category label or use a table'
        raise LayoutError, "#{@chart.type.capitalize} labels cannot be placed faithfully; #{remedy}"
      end
      raise LayoutError, 'Radar legend cannot be placed faithfully; use a comparison table or small multiples' if @width > 1800
      @cx = @width / 2.0
    end

    def draw_polar
      rings = RING_FRACTIONS.map.with_index do |fraction, index|
        radius = BigDecimal(RADIUS.to_s) * fraction
        %(<circle data-polar-ring="#{index + 1}" data-fraction="#{canonical(fraction)}" cx="#{coord(@cx)}" cy="#{CENTER_Y}" r="#{coord(radius)}" fill="none" stroke="#{@palette[:rule]}" stroke-width="0.8"/>)
      end.join
      count = @chart.categories.size
      spokes = @chart.categories.map.with_index do |item, index|
        x, y = endpoint(RADIUS, index, count)
        %(<line data-polar-spoke="#{esc(item.id)}" x1="#{coord(@cx)}" y1="#{CENTER_Y}" x2="#{coord(x)}" y2="#{coord(y)}" stroke="#{@palette[:rule]}" stroke-width="0.8"/>)
      end.join
      marks = @chart.categories.map.with_index do |item, index|
        radius = mapped_radius(item.value)
        x, y = endpoint(radius, index, count)
        ray = item.value.zero? ? '' : %(<line data-polar-ray="#{esc(item.id)}" data-value="#{canonical(item.value)}" data-radius="#{canonical(radius)}" x1="#{coord(@cx)}" y1="#{CENTER_Y}" x2="#{coord(x)}" y2="#{coord(y)}" stroke="#{item.focal ? @palette[:accent] : @palette[:muted]}" stroke-width="#{item.focal ? '2.4' : '2'}"/>)
        marker = item.value.zero? ? '' : %(<circle data-polar-marker="#{esc(item.id)}" data-value="#{canonical(item.value)}" data-radius="#{canonical(radius)}" cx="#{coord(x)}" cy="#{coord(y)}" r="#{item.focal ? '5' : '4'}" fill="#{@palette[:paper]}" stroke="#{item.focal ? @palette[:accent] : @palette[:muted]}" stroke-width="1.2"/>)
        lx, ly = endpoint(RADIUS + 28, index, count)
        anchor = label_anchor(index, count)
        category_y = ly + 5
        value_y = category_y + 24
        ray + marker + %(<text data-polar-category="#{esc(item.id)}" x="#{coord(lx)}" y="#{coord(category_y)}" text-anchor="#{anchor}" fill="#{@palette[:ink]}" font-family="Geist,'Helvetica Neue',Arial,sans-serif" font-size="14" font-weight="600">#{esc(item.label)}</text><text data-polar-value="#{esc(item.id)}" data-value="#{canonical(item.value)}" data-radius="#{canonical(radius)}" x="#{coord(lx)}" y="#{coord(value_y)}" text-anchor="#{anchor}" fill="#{item.focal ? @palette[:accent] : @palette[:muted]}" font-family="'Geist Mono',ui-monospace,monospace" font-size="12">#{esc(format_value(item.value))}</text>)
      end.join
      zero = %(<text data-polar-zero="true" x="#{coord(@cx)}" y="#{CENTER_Y + 4}" text-anchor="middle" fill="#{@palette[:muted]}" font-family="'Geist Mono',ui-monospace,monospace" font-size="12">0</text>)
      tick_labels = RING_FRACTIONS.map do |fraction|
        value = @chart.scale_domain.max * fraction
        y = CENTER_Y - RADIUS * fraction.to_f
        %(<text data-polar-scale-value="#{canonical(value)}" x="#{coord(@cx - 8)}" y="#{coord(y + 4)}" text-anchor="end" fill="#{@palette[:muted]}" font-family="'Geist Mono',ui-monospace,monospace" font-size="12">#{esc(format_value(value))}</text>)
      end.join
      rings + spokes + tick_labels + marks + zero
    end

    def draw_radar
      count = @chart.criteria.size
      rings = RING_FRACTIONS.map.with_index do |fraction, index|
        points = count.times.map { |i| endpoint(RADIUS * fraction.to_f, i, count).map { |v| coord(v) }.join(',') }.join(' ')
        %(<polygon data-radar-ring="#{index + 1}" data-fraction="#{canonical(fraction)}" points="#{points}" fill="none" stroke="#{@palette[:rule]}" stroke-width="0.8"/>)
      end.join
      spokes = @chart.criteria.map.with_index do |criterion, index|
        x, y = endpoint(RADIUS, index, count)
        %(<line data-radar-spoke="#{esc(criterion.id)}" x1="#{coord(@cx)}" y1="#{CENTER_Y}" x2="#{coord(x)}" y2="#{coord(y)}" stroke="#{@palette[:rule]}" stroke-width="0.8"/>)
      end.join
      labels = @chart.criteria.map.with_index do |criterion, index|
        x, y = endpoint(RADIUS + 26, index, count)
        %(<text data-radar-criterion="#{esc(criterion.id)}" x="#{coord(x)}" y="#{coord(y + 5)}" text-anchor="#{label_anchor(index, count)}" fill="#{@palette[:ink]}" font-family="Geist,'Helvetica Neue',Arial,sans-serif" font-size="14" font-weight="600">#{esc(criterion.label)}</text>)
      end.join
      tick_labels = RING_FRACTIONS.map do |fraction|
        value = @chart.scale_domain.max * fraction
        y = CENTER_Y - RADIUS * fraction.to_f
        %(<text data-radar-scale-value="#{canonical(value)}" x="#{coord(@cx - 8)}" y="#{coord(y + 4)}" text-anchor="end" fill="#{@palette[:muted]}" font-family="'Geist Mono',ui-monospace,monospace" font-size="12">#{esc(format_value(value))}</text>)
      end.join
      entities = @chart.entities.map.with_index do |entity, entity_index|
        vertices = @chart.criteria.map.with_index do |criterion, index|
          value = entity.values.fetch(criterion.id)
          radius = mapped_radius(value)
          x, y = endpoint(radius, index, count)
          [criterion, value, radius, x, y]
        end
        points = vertices.map { |(_, _, _, x, y)| "#{coord(x)},#{coord(y)}" }.join(' ')
        dash = dash_for(entity, entity_index)
        polygon = %(<polygon data-radar-entity="#{esc(entity.id)}" data-focal="#{entity.focal}" points="#{points}" fill="none" stroke="#{entity.focal ? @palette[:accent] : @palette[:muted]}" stroke-width="#{entity.focal ? '2.4' : '1.8'}"#{dash.empty? ? '' : " stroke-dasharray=\"#{dash}\""}/>)
        evidence = vertices.map do |criterion, value, radius, x, y|
          %(<circle data-radar-vertex="#{esc(entity.id)}:#{esc(criterion.id)}" data-value="#{canonical(value)}" data-radius="#{canonical(radius)}" cx="#{coord(x)}" cy="#{coord(y)}" r="#{entity.focal ? '4' : '0'}" fill="#{entity.focal ? @palette[:paper] : 'none'}" stroke="#{entity.focal ? @palette[:accent] : 'none'}" stroke-width="1.2"/>)
        end.join
        polygon + evidence
      end.join
      legend_x = 40.0
      legend = @chart.entities.map.with_index do |entity, index|
        dash = dash_for(entity, index)
        entry = %(<line data-radar-legend="#{esc(entity.id)}" x1="#{coord(legend_x)}" y1="500" x2="#{coord(legend_x + 28)}" y2="500" stroke="#{entity.focal ? @palette[:accent] : @palette[:muted]}" stroke-width="#{entity.focal ? '2.4' : '1.8'}"#{dash.empty? ? '' : " stroke-dasharray=\"#{dash}\""}/><text x="#{coord(legend_x + 38)}" y="504" fill="#{@palette[:ink]}" font-family="'Geist Mono',ui-monospace,monospace" font-size="12">#{esc(entity.label)}</text>)
        legend_x += Text.width(entity.label, 12, font: :mono) + 72
        entry
      end.join
      rings + spokes + tick_labels + entities + labels + legend
    end

    def endpoint(radius, index, count)
      angle = -Math::PI / 2 + 2 * Math::PI * index / count
      [@cx + radius.to_f * Math.cos(angle), CENTER_Y + radius.to_f * Math.sin(angle)]
    end

    def dash_for(entity, index)
      return '' if entity.focal
      nonfocal_index = @chart.entities.take(index + 1).reject(&:focal).size
      DASHES[nonfocal_index]
    end

    def mapped_radius(value)
      ratio = value / @chart.scale_domain.max
      converted = ratio.to_f
      raise LayoutError, 'Radial SVG mapping underflow; use a safer finite scale or a table' if !ratio.zero? && converted.zero?
      result = ratio * RADIUS
      number = result.to_f
      raise LayoutError, 'Radial SVG mapping overflow; use a safer finite scale or a table' unless number.finite?
      result
    end

    def label_anchor(index, count)
      angle = -Math::PI / 2 + 2 * Math::PI * index / count
      cosine = Math.cos(angle)
      return 'middle' if cosine.abs < 0.26
      cosine.positive? ? 'start' : 'end'
    end

    def caption
      max = format_value(@chart.scale_domain.max)
      if @chart.type == :polar
        "RADIUS = VALUE ON LINEAR 0–#{max} #{@chart.unit}; AREA HAS NO MEANING"
      else
        "VERTEX RADIUS = SCORE ON LINEAR 0–#{max} #{@chart.unit}; POLYGON AREA HAS NO MEANING"
      end
    end

    def format_value(value) = Quantitative::Value.format(value, @chart.precision)
    def canonical(value) = Quantitative::Value.canonical(value)
    def coord(value) = format('%.6f', value.to_f).sub(/0+\z/, '').sub(/\.\z/, '')
    def esc(value) = CGI.escapeHTML(value.to_s)
  end
end
