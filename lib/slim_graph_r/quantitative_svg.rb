# frozen_string_literal: true

module SlimGraphR
  class QuantitativeSVG
    DISPLAY_SCALE = 1.143
    TOP = 144
    BOTTOM = 460
    AXIS_LABEL_Y = 486
    CAPTION_Y = 524
    SOURCE_Y = 552
    RIGHT = 40

    def initialize(chart, id: nil)
      @chart = chart
      @id = id || "sgr-#{SecureRandom.hex(6)}"
      raise Error, 'SVG ID must start with a letter and contain only letters, digits, hyphens, underscores' unless @id.match?(/\A[a-zA-Z][a-zA-Z0-9_-]*\z/)
    end

    def render
      measure!
      profile = @chart.style_profile
      light = profile.light.map { |key, value| "--sgr-#{key}:#{value}" }.join(';')
      dark = profile.dark.map { |key, value| "--sgr-#{key}:#{value}" }.join(';')
      type = @chart.type
      body = send("draw_#{type}")
      caption = scale_caption
      source = @chart.source_note
      height = source ? 580 : 552
      display_width = (@width * DISPLAY_SCALE).ceil
      display_height = (height * DISPLAY_SCALE).ceil
      auto_css = @chart.theme == :auto ? "@media(prefers-color-scheme:dark){##{@id}{#{dark}}}[data-theme=dark] ##{@id},[data-sw-theme=dark] ##{@id},.dark ##{@id}{#{dark}}" : ''
      vars = @chart.theme == :dark ? dark : light
      <<~SVG.gsub(/\n\s*/, '')
        <svg xmlns="http://www.w3.org/2000/svg" id="#{@id}" class="sgr-diagram" data-sgr-#{type}="true" data-sgr-theme="#{@chart.theme}" data-sgr-style="#{@chart.style}" data-sgr-display-scale="#{DISPLAY_SCALE}" role="img" aria-labelledby="#{@id}-title #{@id}-desc" viewBox="0 0 #{@width} #{height}" width="#{display_width}" height="#{display_height}" style="display:block;margin:0 auto;width:100%;height:auto;min-width:#{display_width}px">
          <title id="#{@id}-title">#{esc(@chart.title)}</title><desc id="#{@id}-desc">#{esc(@chart.accessible_description)}</desc>
          <style>##{@id}{#{vars};color:var(--sgr-ink);font-family:Geist,'Helvetica Neue',Arial,sans-serif}#{auto_css}##{@id} text{fill:var(--sgr-ink);font-size:14px}##{@id} .sgr-title{font-family:#{profile.heading_family};font-size:30px;font-weight:#{profile.heading_weight}}##{@id} .sgr-meta{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted);font-size:12px}##{@id} .sgr-label{font-size:14px;font-weight:600}##{@id} .sgr-value{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted);font-size:12px}##{@id} .sgr-focal-value{fill:var(--sgr-accent);font-weight:600}</style>
          <rect x="0" y="0" width="#{@width}" height="#{height}" fill="var(--sgr-paper)"/>
          <text x="40" y="48" class="sgr-title">#{esc(@chart.title)}</text><line x1="40" y1="88" x2="#{@width - 40}" y2="88" stroke="var(--sgr-rule)" stroke-width="1"/>
          <metadata data-chart="#{type}" #{metadata_domains} #{metadata_mapping} data-notation="plain" data-precision="#{@chart.precision}"#{@chart.auto_reference? ? ' data-auto-reference="true"' : ''}>#{esc(@chart.accessible_description)}</metadata>
          #{body}
          <text x="40" y="#{CAPTION_Y}" class="sgr-meta" data-scale-caption="true">#{esc(caption)}</text>
          #{source ? %(<text x="40" y="#{SOURCE_Y}" class="sgr-meta" data-source-note="true">#{esc(source)}</text>) : ''}
        </svg>
      SVG
    end

    private

    def measure!
      case @chart.type
      when :bar
        if @chart.orientation == :horizontal
          label = @chart.categories.map { |item| Text.width(item.label, 14) }.max
          raise LayoutError, 'Horizontal bar labels do not fit; shorten a label, enlarge the canvas, or split the chart' if label > 480
          @left = [184, Text.grid(label + 56)].max
          value_width = @chart.categories.map { |item| Text.width(display(item.value, @chart.unit), 12, font: :mono) }.max
          @right_gutter = Text.grid(value_width + 28)
          @width = [1000, @left + 620 + @right_gutter].max
        else
          label = @chart.categories.map { |item| Text.width(item.label, 14) }.max
          required = 120 + @chart.categories.size * [80, Text.grid(label + 24)].max
          raise LayoutError, 'Vertical bar labels do not fit; shorten a label, enlarge the canvas, or split the chart' if required > 1440
          @width = [1000, required].max
          @left = 92
        end
      when :line
        x_label = @chart.x_domain.map { |item| Text.width(item, 12, font: :mono) }.max
        required = 132 + (@chart.x_domain.size - 1) * [44, Text.grid(x_label + 16)].max
        raise LayoutError, 'Line x-axis labels do not fit; shorten labels, enlarge the canvas, or split the chart' if required > 1440
        @width = [1000, required].max
        @left = 92
      when :scatter
        annotation = @chart.points.select(&:annotate).map { |item| Text.width(item.label, 14) }.max || 0
        raise LayoutError, 'Scatter annotations do not fit; shorten a label, enlarge the canvas, or split the chart' if annotation > 360
        units_width = Text.width(@chart.x_unit, 12, font: :mono) + Text.width(@chart.y_unit, 12, font: :mono)
        raise LayoutError, 'Scatter axis units do not fit; shorten a unit, enlarge the canvas, or split the chart' if units_width + 120 > 920
        @width = 1000
        @left = 92
      end
      @plot_right = @width - (@right_gutter || RIGHT)
      @plot_width = @plot_right - @left
      @plot_height = BOTTOM - TOP
      heading_font = @chart.style_profile.heading_font
      if Text.width(@chart.title, 30, font: heading_font) > @width - 80
        raise LayoutError, 'Chart title does not fit; shorten the title, enlarge the canvas, or split the chart'
      end
      if @chart.source_note && Text.width(@chart.source_note, 12, font: :mono) > @width - 80
        raise LayoutError, 'Source note does not fit; shorten the source note, enlarge the canvas, or split the chart'
      end
      if Text.width(scale_caption, 12, font: :mono) > @width - 80
        raise LayoutError, 'Scale caption does not fit; reduce precision or unit length, enlarge the canvas, or split the chart'
      end
    end

    def draw_bar
      return draw_horizontal_bar if @chart.orientation == :horizontal
      scale = @chart.domain
      ticks = draw_y_ticks(scale, @chart.unit)
      baseline = map_y(BigDecimal('0'), scale)
      pitch = @plot_width.to_f / @chart.categories.size
      bar_width = [pitch * 0.58, 92].min
      marks = @chart.categories.each_with_index.map do |item, index|
        x = @left + pitch * index + (pitch - bar_width) / 2
        y = map_y(item.value, scale)
        label_y = item.value.negative? ? [y + 22, BOTTOM - 8].min : [y - 10, TOP + 14].max
        rect = if item.value.zero?
          %(<circle data-category="#{esc(item.id)}" data-value="#{canonical(item.value)}" data-zero="true" data-focal="#{item.focal}" cx="#{coord(x + bar_width / 2)}" cy="#{coord(baseline)}" r="0" fill="none"/>)
        else
          top = [y, baseline].min
          height = (y - baseline).abs
          %(<rect data-bar="#{esc(item.id)}" data-value="#{canonical(item.value)}" data-focal="#{item.focal}" data-zero-baseline="#{coord(baseline)}" x="#{coord(x)}" y="#{coord(top)}" width="#{coord(bar_width)}" height="#{coord(height)}" fill="#{item.focal ? 'var(--sgr-tint)' : 'var(--sgr-secondary)'}" stroke="#{item.focal ? 'var(--sgr-accent)' : 'var(--sgr-muted)'}" stroke-width="1.2"/>)
        end
        rect + %(<text x="#{coord(x + bar_width / 2)}" y="#{coord(label_y)}" text-anchor="middle" class="sgr-value#{item.focal ? ' sgr-focal-value' : ''}">#{esc(display(item.value, @chart.unit))}</text><text x="#{coord(x + bar_width / 2)}" y="#{AXIS_LABEL_Y}" text-anchor="middle" class="sgr-label">#{esc(item.label)}</text>)
      end.join
      ticks + %(<line data-zero-axis="true" x1="#{@left}" y1="#{coord(baseline)}" x2="#{@plot_right}" y2="#{coord(baseline)}" stroke="var(--sgr-ink)" stroke-width="1.2"/>) + marks
    end

    def draw_horizontal_bar
      scale = @chart.domain
      baseline = map_x(BigDecimal('0'), scale)
      pitch = @plot_height.to_f / @chart.categories.size
      bar_height = [pitch * 0.56, 48].min
      ticks = draw_x_ticks(scale, @chart.unit)
      marks = @chart.categories.each_with_index.map do |item, index|
        y = TOP + pitch * index + (pitch - bar_height) / 2
        x = map_x(item.value, scale)
        shape = if item.value.zero?
          %(<circle data-category="#{esc(item.id)}" data-value="#{canonical(item.value)}" data-zero="true" data-focal="#{item.focal}" cx="#{coord(baseline)}" cy="#{coord(y + bar_height / 2)}" r="0" fill="none"/>)
        else
          left = [x, baseline].min
          %(<rect data-bar="#{esc(item.id)}" data-value="#{canonical(item.value)}" data-focal="#{item.focal}" data-zero-baseline="#{coord(baseline)}" x="#{coord(left)}" y="#{coord(y)}" width="#{coord((x - baseline).abs)}" height="#{coord(bar_height)}" fill="#{item.focal ? 'var(--sgr-tint)' : 'var(--sgr-secondary)'}" stroke="#{item.focal ? 'var(--sgr-accent)' : 'var(--sgr-muted)'}" stroke-width="1.2"/>)
        end
        %(<text x="#{@left - 16}" y="#{coord(y + bar_height / 2 + 5)}" text-anchor="end" class="sgr-label">#{esc(item.label)}</text>) + shape + %(<text x="#{coord(item.value.negative? ? x - 10 : x + 10)}" y="#{coord(y + bar_height / 2 + 4)}" text-anchor="#{item.value.negative? ? 'end' : 'start'}" class="sgr-value#{item.focal ? ' sgr-focal-value' : ''}">#{esc(display(item.value, @chart.unit))}</text>)
      end.join
      ticks + %(<line data-zero-axis="true" x1="#{coord(baseline)}" y1="#{TOP}" x2="#{coord(baseline)}" y2="#{BOTTOM}" stroke="var(--sgr-ink)" stroke-width="1.2"/>) + marks
    end

    def draw_line
      scale = @chart.domain
      ticks = draw_y_ticks(scale, @chart.unit)
      xs = line_x_positions
      zero = map_y(BigDecimal('0'), scale)
      zero_rule = scale.min <= 0 && scale.max >= 0 ? %(<line data-zero-axis="true" x1="#{@left}" y1="#{coord(zero)}" x2="#{@plot_right}" y2="#{coord(zero)}" stroke="var(--sgr-rule)" stroke-width="1.2"/>) : ''
      x_labels = selected_line_labels(xs).map { |i| %(<text data-x-position="#{i}" x="#{coord(xs[i])}" y="#{AXIS_LABEL_Y}" text-anchor="middle" class="sgr-meta">#{esc(@chart.x_domain[i])}</text>) }.join
      gaps = []
      content = @chart.series_list.map do |series|
        segments = []
        vertices = []
        series.observations.each_with_index do |obs, i|
          if obs.gap
            gaps << %(<gap data-gap="true" data-series="#{esc(series.id)}" data-x-index="#{i}" reason="#{esc(obs.reason)}"/>)
            next
          end
          y = map_y(obs.value, scale)
          vertices << %(<circle data-series="#{esc(series.id)}" data-value="#{canonical(obs.value)}" data-focal="#{series.focal}" data-x-index="#{i}" cx="#{coord(xs[i])}" cy="#{coord(y)}" r="#{series.focal ? 4 : 3}" fill="#{series.focal ? 'var(--sgr-accent)' : 'var(--sgr-paper)'}" stroke="#{series.focal ? 'var(--sgr-accent)' : 'var(--sgr-muted)'}" stroke-width="1.2"/>)
          if i.positive? && !series.observations[i - 1].gap
            prior = series.observations[i - 1]
            segments << %(<line data-segment="#{esc(series.id)}:#{i - 1}-#{i}" data-from="#{canonical(prior.value)}" data-to="#{canonical(obs.value)}" x1="#{coord(xs[i - 1])}" y1="#{coord(map_y(prior.value, scale))}" x2="#{coord(xs[i])}" y2="#{coord(y)}" stroke="#{series.focal ? 'var(--sgr-accent)' : 'var(--sgr-muted)'}" stroke-width="#{series.focal ? 2.4 : 1.6}"/>)
          end
        end
        segments.join + vertices.join
      end.join
      legend_x = [@left, 40 + Text.width(@chart.unit, 12, font: :mono) + 36].max
      legend = @chart.series_list.map do |item|
        entry = %(<line x1="#{coord(legend_x)}" y1="112" x2="#{coord(legend_x + 28)}" y2="112" stroke="#{item.focal ? 'var(--sgr-accent)' : 'var(--sgr-muted)'}" stroke-width="#{item.focal ? 2.4 : 1.6}"/><text x="#{coord(legend_x + 38)}" y="116" class="sgr-meta">#{esc(item.label)}</text>)
        legend_x += 62 + Text.width(item.label, 12, font: :mono)
        entry
      end.join
      raise LayoutError, 'Line legend does not fit; shorten a series label, enlarge the canvas, or split the chart' if legend_x > @plot_right
      warning = @chart.x_axis_kind == :ordinal ? %(<text x="#{@plot_right}" y="136" text-anchor="end" class="sgr-meta" data-ordinal-warning="true">SPACING IS ORDINAL, NOT ELAPSED TIME</text>) : ''
      %(<metadata>#{gaps.join}</metadata>) + ticks + zero_rule + legend + warning + content + x_labels
    end

    def draw_scatter
      x_scale, y_scale = @chart.x_domain_scale, @chart.y_domain_scale
      axes = draw_x_ticks(x_scale, @chart.x_unit) + draw_y_ticks(y_scale, @chart.y_unit)
      placed = []
      marks = @chart.points.map do |item|
        x, y = map_x(item.x, x_scale), map_y(item.y, y_scale)
        identity = item.anonymous ? 'data-anonymous-point="true"' : %(data-point="#{esc(item.id)}")
        mark = %(<circle #{identity} data-x="#{canonical(item.x)}" data-y="#{canonical(item.y)}" data-focal="#{item.focal}" cx="#{coord(x)}" cy="#{coord(y)}" r="#{item.focal ? 6 : 5}" fill="#{item.focal ? 'var(--sgr-tint)' : 'var(--sgr-secondary)'}" stroke="#{item.focal ? 'var(--sgr-accent)' : 'var(--sgr-muted)'}" stroke-width="1.2"/>)
        next mark unless item.annotate
        label_width = Text.width(item.label, 14)
        candidates = [
          [x + 10, y - 14, 'start'], [x - 10, y - 14, 'end'],
          [x + 10, y + 28, 'start'], [x - 10, y + 28, 'end'],
          [x + 10, y - 44, 'start'], [x - 10, y - 44, 'end'],
          [x + 10, y + 54, 'start'], [x - 10, y + 54, 'end']
        ]
        choice = candidates.find do |label_x, label_y, anchor|
          left = anchor == 'end' ? label_x - label_width : label_x
          box = [left, label_y - 15, left + label_width, label_y + 3]
          inside = box[0] >= @left && box[2] <= @plot_right && box[1] >= TOP && box[3] <= BOTTOM
          clear = placed.none? { |other| boxes_overlap?(box, other, 6) }
          inside && clear && (x < box[0] - 7 || x > box[2] + 7 || y < box[1] - 7 || y > box[3] + 7)
        end
        raise LayoutError, 'Scatter annotations do not fit without overlap; shorten a label, enlarge the canvas, or split the chart' unless choice
        label_x, label_y, anchor = choice
        left = anchor == 'end' ? label_x - label_width : label_x
        placed << [left, label_y - 15, left + label_width, label_y + 3]
        mark + %(<text data-annotation="#{esc(item.id)}" x="#{coord(label_x)}" y="#{coord(label_y)}" text-anchor="#{anchor}" class="sgr-label">#{esc(item.label)}</text>)
      end.join
      axes + marks
    end

    def draw_y_ticks(scale, unit)
      tick_values(scale).map do |value|
        y = map_y(value, scale)
        %(<line x1="#{@left}" y1="#{coord(y)}" x2="#{@plot_right}" y2="#{coord(y)}" stroke="var(--sgr-rule)" stroke-width="0.8"/><text data-tick="y" data-value="#{canonical(value)}" x="#{@left - 12}" y="#{coord(y + 4)}" text-anchor="end" class="sgr-meta">#{esc(Quantitative::Value.format(value, @chart.precision))}</text>)
      end.join + %(<text x="40" y="116" class="sgr-meta">#{esc(unit)}</text>)
    end

    def draw_x_ticks(scale, unit)
      tick_values(scale).map do |value|
        x = map_x(value, scale)
        %(<line x1="#{coord(x)}" y1="#{TOP}" x2="#{coord(x)}" y2="#{BOTTOM}" stroke="var(--sgr-rule)" stroke-width="0.8"/><text data-tick="x" data-value="#{canonical(value)}" x="#{coord(x)}" y="#{AXIS_LABEL_Y}" text-anchor="middle" class="sgr-meta">#{esc(Quantitative::Value.format(value, @chart.precision))}</text>)
      end.join + %(<text x="#{@plot_right}" y="116" text-anchor="end" class="sgr-meta">#{esc(unit)}</text>)
    end

    def tick_values(scale)
      span = scale.max - scale.min
      5.times.map { |i| scale.min + span * BigDecimal(i.to_s) / 4 }
    end

    def line_x_positions
      if @chart.x_axis_kind == :ordinal
        pitch = BigDecimal(@plot_width.to_s) / (@chart.x_domain.size - 1)
        @chart.x_domain.size.times.map { |i| safe_float(BigDecimal(@left.to_s) + pitch * i, 'line ordinal coordinate') }
      else
        dates = @chart.x_domain.map { |value| Date.iso8601(value) }
        span = BigDecimal((dates.last - dates.first).to_i.to_s)
        dates.map do |date|
          ratio = BigDecimal((date - dates.first).to_i.to_s) / span
          safe_float(BigDecimal(@left.to_s) + ratio * @plot_width, 'line elapsed-day coordinate')
        end
      end
    end

    def selected_line_labels(xs)
      candidates = (0...@chart.x_domain.size).to_a
      selected = [candidates.first, candidates.last].uniq
      candidates[1...-1].to_a.each do |index|
        width = Text.width(@chart.x_domain[index], 12, font: :mono)
        box = [xs[index] - width / 2, xs[index] + width / 2]
        next if selected.any? do |other_index|
          other_width = Text.width(@chart.x_domain[other_index], 12, font: :mono)
          other = [xs[other_index] - other_width / 2, xs[other_index] + other_width / 2]
          box[0] < other[1] + 12 && box[1] > other[0] - 12
        end
        selected << index
      end
      selected.sort
    end

    def boxes_overlap?(one, two, padding)
      one[0] < two[2] + padding && one[2] > two[0] - padding && one[1] < two[3] + padding && one[3] > two[1] - padding
    end

    def map_x(value, scale)
      ratio = mapping_ratio(value, scale, 'horizontal')
      safe_float(BigDecimal(@left.to_s) + ratio * @plot_width, 'horizontal SVG coordinate')
    end

    def map_y(value, scale)
      ratio = mapping_ratio(value, scale, 'vertical')
      safe_float(BigDecimal(BOTTOM.to_s) - ratio * @plot_height, 'vertical SVG coordinate')
    end

    def mapping_ratio(value, scale, axis)
      [value, scale.min, scale.max, scale.max - scale.min].each { |number| safe_float(number, "#{axis} scale") }
      delta = value - scale.min
      ratio = delta / (scale.max - scale.min)
      if !delta.zero? && ratio.to_f.zero?
        raise LayoutError, "#{axis} SVG mapping underflow; use a safer finite scale or split the chart"
      end
      safe_float(ratio, "#{axis} SVG mapping")
      ratio
    end

    def safe_float(value, context)
      converted = value.to_f
      raise LayoutError, "#{context} overflow; use a safer finite scale or split the chart" unless converted.finite?
      raise LayoutError, "#{context} underflow; use a safer finite scale or split the chart" if !value.zero? && converted.zero?
      converted
    end

    def coord(value)
      number = value.is_a?(BigDecimal) ? safe_float(value, 'SVG coordinate') : value.to_f
      format('%.6f', number).sub(/0+\z/, '').sub(/\.\z/, '')
    end

    def display(value, unit) = "#{Quantitative::Value.format(value, @chart.precision)} #{unit}"
    def canonical(value) = Quantitative::Value.canonical(value)
    def esc(value) = CGI.escapeHTML(value.to_s)

    def metadata_domains
      if @chart.type == :scatter
        %(data-x-domain-min="#{canonical(@chart.x_domain_scale.min)}" data-x-domain-max="#{canonical(@chart.x_domain_scale.max)}" data-y-domain-min="#{canonical(@chart.y_domain_scale.min)}" data-y-domain-max="#{canonical(@chart.y_domain_scale.max)}")
      else
        %(data-domain-min="#{canonical(@chart.domain.min)}" data-domain-max="#{canonical(@chart.domain.max)}")
      end
    end

    def metadata_mapping
      plot = %(data-mapping="linear" data-plot-left="#{coord(@left)}" data-plot-right="#{coord(@plot_right)}" data-plot-top="#{TOP}" data-plot-bottom="#{BOTTOM}")
      case @chart.type
      when :bar
        factor = (@chart.orientation == :horizontal ? BigDecimal(@plot_width.to_s) : BigDecimal(@plot_height.to_s)) / (@chart.domain.max - @chart.domain.min)
        axis = @chart.orientation == :horizontal ? 'x' : 'y'
        zero = @chart.orientation == :horizontal ? map_x(BigDecimal('0'), @chart.domain) : map_y(BigDecimal('0'), @chart.domain)
        %(#{plot} data-orientation="#{@chart.orientation}" data-#{axis}-scale-factor="#{canonical(factor)}" data-zero-coordinate="#{coord(zero)}")
      when :line
        y_factor = BigDecimal(@plot_height.to_s) / (@chart.domain.max - @chart.domain.min)
        x_factor = if @chart.x_axis_kind == :ordinal
          BigDecimal(@plot_width.to_s) / (@chart.x_domain.size - 1)
        else
          days = (Date.iso8601(@chart.x_domain.last) - Date.iso8601(@chart.x_domain.first)).to_i
          BigDecimal(@plot_width.to_s) / days
        end
        %(#{plot} data-x-mapping="#{@chart.x_axis_kind}" data-x-scale-factor="#{canonical(x_factor)}" data-y-scale-factor="#{canonical(y_factor)}")
      when :scatter
        x_factor = BigDecimal(@plot_width.to_s) / (@chart.x_domain_scale.max - @chart.x_domain_scale.min)
        y_factor = BigDecimal(@plot_height.to_s) / (@chart.y_domain_scale.max - @chart.y_domain_scale.min)
        %(#{plot} data-x-scale-factor="#{canonical(x_factor)}" data-y-scale-factor="#{canonical(y_factor)}")
      end
    end

    def scale_caption
      if @chart.type == :scatter
        "LINEAR POSITION · X #{@chart.x_unit} #{Quantitative::Value.format(@chart.x_domain_scale.min, @chart.precision)}–#{Quantitative::Value.format(@chart.x_domain_scale.max, @chart.precision)} · Y #{@chart.y_unit} #{Quantitative::Value.format(@chart.y_domain_scale.min, @chart.precision)}–#{Quantitative::Value.format(@chart.y_domain_scale.max, @chart.precision)}"
      else
        prefix = @chart.auto_reference? ? 'AUTO REFERENCE DOMAIN ' : 'LINEAR DOMAIN '
        "#{prefix}#{unicode(Quantitative::Value.format(@chart.domain.min, @chart.precision))}–#{unicode(Quantitative::Value.format(@chart.domain.max, @chart.precision))} #{@chart.unit}"
      end
    end

    def unicode(value) = value.sub(/\A-/, '−')
  end
end
