# frozen_string_literal: true

module SlimGraphR
  class AreaConservationSVG
    DISPLAY_SCALE = 1.143

    def initialize(chart, id: nil)
      @chart = chart
      @id = id || "sgr-#{SecureRandom.hex(6)}"
      raise Error, 'SVG ID must start with a letter and contain only letters, digits, hyphens, underscores' unless @id.match?(/\A[a-zA-Z][a-zA-Z0-9_-]*\z/)
    end

    def render
      profile = @chart.style_profile
      layout = @chart.layout
      width = @chart.type == :treemap ? 1000 : layout.width
      body, content_height = @chart.type == :treemap ? draw_treemap(layout) : draw_sankey(layout)
      source_y = content_height - 28
      vars = palette(profile)
      dark = palette(profile, dark: true)
      auto_css = @chart.theme == :auto ? "@media(prefers-color-scheme:dark){##{@id}{#{dark}}}[data-theme=dark] ##{@id},[data-sw-theme=dark] ##{@id},.dark ##{@id}{#{dark}}" : ''
      selected = @chart.theme == :dark ? dark : vars
      display_width = (width * DISPLAY_SCALE).ceil
      display_height = (content_height * DISPLAY_SCALE).ceil
      <<~SVG.gsub(/\n\s*/, '')
        <svg xmlns="http://www.w3.org/2000/svg" id="#{@id}" class="sgr-diagram" data-sgr-#{@chart.type}="true" data-sgr-theme="#{@chart.theme}" data-sgr-style="#{@chart.style}" data-sgr-display-scale="#{DISPLAY_SCALE}" role="img" aria-labelledby="#{@id}-title #{@id}-desc" viewBox="0 0 #{width} #{content_height}" width="#{display_width}" height="#{display_height}" style="display:block;margin:0 auto;width:100%;height:auto;min-width:#{display_width}px">
          <title id="#{@id}-title">#{esc(@chart.title)}</title><desc id="#{@id}-desc">#{esc(@chart.accessible_description)}</desc>
          <style>##{@id}{#{selected};color:var(--sgr-ink);font-family:Geist,'Helvetica Neue',Arial,sans-serif}#{auto_css}##{@id} text{fill:var(--sgr-ink);font-size:14px}##{@id} .sgr-title{font-family:#{profile.heading_family};font-size:30px;font-weight:#{profile.heading_weight}}##{@id} .sgr-meta{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted);font-size:12px}##{@id} .sgr-label{font-size:14px;font-weight:600}##{@id} .sgr-value{font-family:'Geist Mono',ui-monospace,monospace;fill:var(--sgr-muted);font-size:12px}</style>
          <rect x="0" y="0" width="#{width}" height="#{content_height}" fill="var(--sgr-paper)"/>
          <text x="40" y="48" class="sgr-title">#{esc(@chart.title)}</text><line x1="40" y1="88" x2="#{width - 40}" y2="88" stroke="var(--sgr-rule)" stroke-width="1"/>
          #{body}
          #{@chart.source_note ? %(<text x="40" y="#{source_y}" class="sgr-meta" data-source-note="true">#{esc(@chart.source_note)}</text>) : ''}
        </svg>
      SVG
    end

    private

    def palette(profile, dark: false)
      profile.public_send(dark ? :dark : :light).map { |key, value| "--sgr-#{key}:#{value}" }.join(';')
    end

    def draw_treemap(layout)
      total = @chart.items.sum(BigDecimal('0'), &:value)
      metadata = %(<metadata data-area-total="#{canonical(total)}" data-plot-x="#{coord(layout.plot_x)}" data-plot-y="#{coord(layout.plot_y)}" data-plot-width="#{coord(layout.plot_width)}" data-plot-height="#{coord(layout.plot_height)}" data-encoding="area=value/sum-positive" data-precision="#{@chart.precision}" data-notation="plain">#{esc(@chart.accessible_description)}</metadata>)
      cells = layout.cells.map do |cell|
        item = cell.item
        rect = %(<rect data-treemap-cell="#{esc(item.id)}" data-value="#{canonical(item.value)}" data-share="#{canonical(cell.share)}" data-focal="#{item.focal}" x="#{coord(cell.x)}" y="#{coord(cell.y)}" width="#{coord(cell.width)}" height="#{coord(cell.height)}" fill="#{item.focal ? 'var(--sgr-tint)' : 'var(--sgr-secondary)'}" stroke="#{item.focal ? 'var(--sgr-accent)' : 'var(--sgr-rule)'}" stroke-width="#{item.focal ? '1.5' : '1'}"/>)
        next rect if cell.external
        x, y = cell.x + 12, cell.y + 24
        rect + %(<text x="#{coord(x)}" y="#{coord(y)}" class="sgr-label">#{esc(item.label)}</text><text x="#{coord(x)}" y="#{coord(y + 20)}" class="sgr-value">#{esc(value_and_share(item, cell.share))}</text>)
      end.join
      legend_items = @chart.items.map.with_index do |item, index|
        cell = layout.cells.find { |candidate| candidate.item.equal?(item) }
        zero = item.value.zero?
        share = zero ? BigDecimal('0') : cell.share
        y = 586 + index * 24
        attrs = zero ? %(data-treemap-zero="#{esc(item.id)}") : (cell.external ? %(data-external-legend="#{esc(item.id)}") : %(data-treemap-legend="#{esc(item.id)}"))
        %(<g #{attrs} data-value="#{canonical(item.value)}" data-share="#{canonical(share)}"><rect x="40" y="#{y - 11}" width="12" height="12" fill="#{zero ? 'none' : (item.focal ? 'var(--sgr-tint)' : 'var(--sgr-secondary)')}" stroke="#{item.focal ? 'var(--sgr-accent)' : 'var(--sgr-rule)'}"/><text x="64" y="#{y}" class="sgr-meta">#{esc(item.label)} · #{esc(value_and_share(item, share))}#{zero ? ' · NO CELL' : ''}</text></g>)
      end.join
      height = 630 + @chart.items.length * 24 + (@chart.source_note ? 28 : 0)
      caption = %(<text x="40" y="570" class="sgr-meta" data-area-caption="true">AREA = VALUE / SUM OF POSITIVE VALUES · ZERO HAS NO CELL</text>)
      [metadata + cells + caption + legend_items, height]
    end

    def draw_sankey(layout)
      metadata = %(<metadata data-conservation="strict-balanced" data-px-per-unit="#{canonical(layout.px_per_unit)}" data-stage-total="#{canonical(@chart.stage_total)}" data-unit="#{esc(@chart.unit)}" data-precision="#{@chart.precision}" data-notation="plain">#{esc(@chart.accessible_description)}</metadata>)
      headers = @chart.stages.each_with_index.map do |stage, index|
        %(<text x="#{coord(AreaConservation::SankeyLayout::XS[index] + 6)}" y="112" text-anchor="middle" class="sgr-meta" data-sankey-stage="#{esc(stage.id)}" data-total="#{canonical(@chart.stage_total)}">#{esc(stage.label.upcase)}</text>)
      end.join
      ribbons = layout.ribbons.map do |ribbon|
        sx = ribbon.source.x + ribbon.source.width
        tx = ribbon.target.x
        sy0 = ribbon.source.y + ribbon.source_start
        sy1 = ribbon.source.y + ribbon.source_end
        ty0 = ribbon.target.y + ribbon.target_start
        ty1 = ribbon.target.y + ribbon.target_end
        mid = (sx + tx) / 2
        d = "M #{coord(sx)},#{coord(sy0)} C #{coord(mid)},#{coord(sy0)} #{coord(mid)},#{coord(ty0)} #{coord(tx)},#{coord(ty0)} L #{coord(tx)},#{coord(ty1)} C #{coord(mid)},#{coord(ty1)} #{coord(mid)},#{coord(sy1)} #{coord(sx)},#{coord(sy1)} Z"
        %(<path data-sankey-flow="#{esc(ribbon.flow.from)}:#{esc(ribbon.flow.to)}" data-focal="#{ribbon.flow.focal}" data-from="#{esc(ribbon.flow.from)}" data-to="#{esc(ribbon.flow.to)}" data-value="#{canonical(ribbon.flow.value)}" data-thickness="#{canonical(ribbon.thickness)}" data-source-offset-start="#{canonical(ribbon.source_start)}" data-source-offset-end="#{canonical(ribbon.source_end)}" data-target-offset-start="#{canonical(ribbon.target_start)}" data-target-offset-end="#{canonical(ribbon.target_end)}" d="#{d}" fill="#{ribbon.flow.focal ? 'var(--sgr-accent)' : 'var(--sgr-muted)'}" fill-opacity="#{ribbon.flow.focal ? '0.28' : '0.24'}"/>)
      end.join
      nodes = layout.node_boxes.map do |box|
        node = box.node
        stage_index = @chart.stages.index { |stage| stage.id == node.stage }
        if stage_index == 1
          label_x, label_y, anchor = box.x + box.width / 2, box.y - 24, 'middle'
        else
          label_x = stage_index.zero? ? box.x - 12 : box.x + box.width + 12
          label_y = box.y + 16
          anchor = stage_index.zero? ? 'end' : 'start'
        end
        %(<rect data-sankey-node="#{esc(node.id)}" data-stage="#{esc(node.stage)}" data-value="#{canonical(node.value)}" data-in-total="#{canonical(box.incoming)}" data-out-total="#{canonical(box.outgoing)}" x="#{coord(box.x)}" y="#{coord(box.y)}" width="#{coord(box.width)}" height="#{canonical(box.height)}" fill="var(--sgr-ink)"/><text x="#{coord(label_x)}" y="#{coord(label_y)}" text-anchor="#{anchor}" class="sgr-label">#{esc(node.label)}</text><text x="#{coord(label_x)}" y="#{coord(label_y + 16)}" text-anchor="#{anchor}" class="sgr-value">#{esc(display(node.value))}</text>)
      end.join
      caption_y = layout.height - 44
      caption = %(<text x="40" y="#{caption_y}" class="sgr-meta" data-conservation-caption="true">STRICT CONSERVATION VERIFIED · ONE SCALE #{esc(Quantitative::Value.format(layout.px_per_unit, 6))} PX/#{esc(@chart.unit)}</text>)
      focal = @chart.flows.select(&:focal)
      legend = focal.empty? ? '' : %(<g data-sankey-legend="true"><rect x="40" y="#{caption_y - 28}" width="16" height="8" fill="var(--sgr-accent)" fill-opacity="0.28"/><text x="64" y="#{caption_y - 20}" class="sgr-meta">FOCAL FLOW#{focal.size == 1 ? '' : 'S'} · #{esc(focal.map { |flow| "#{flow.from} → #{flow.to}" }.join(', '))}</text></g>)
      [metadata + headers + ribbons + nodes + legend + caption, layout.height + (@chart.source_note ? 28 : 0)]
    end

    def value_and_share(item, share)
      "#{Quantitative::Value.format(item.value, @chart.precision)} #{@chart.unit} · #{Quantitative::Value.format(share * 100, @chart.precision)}%"
    end

    def display(value) = "#{Quantitative::Value.format(value, @chart.precision)} #{@chart.unit}"
    def canonical(value) = Quantitative::Value.canonical(value)
    def coord(value)
      return value.to_s unless value.is_a?(BigDecimal)
      converted = value.to_f
      raise LayoutError, 'SVG coordinate overflow; use safer finite values or split the chart' unless converted.finite?
      raise LayoutError, 'SVG coordinate underflow; use safer finite values or split the chart' if !value.zero? && converted.zero?
      value.to_s('F')
    end
    def esc(value) = CGI.escapeHTML(value.to_s)
  end
end
