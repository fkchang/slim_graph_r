# frozen_string_literal: true
module SlimGraphR
  class SVG
    private

    def draw_dp_integration
      @s.routes.each { |route| draw_integration_route(route) }
      @s.layer_services.each { |entry| draw_integration_layer_route(entry) }
      draw_integration_zone
      @s.side_cards.each { |entry| draw_integration_side_card(entry) }
      add '<!-- Row services use fixed 160px cards distributed across the platform zone to reserve protocol space. -->'
      @s.components.each { |entry| draw_integration_component(entry) }
      @s.layer_services.each { |entry| draw_integration_layer_card(entry) }
      @s.routes.each { |route| draw_integration_protocol_label(route[:label]) if route[:label] }
      @s.layer_services.each { |entry| draw_integration_layer_label(entry) }
      draw_integration_legend
    end

    def draw_integration_zone
      zone = @s.zone
      rect(zone[:x], zone[:y], zone[:width], zone[:height], rx: 8, class: 'sgr-integration-zone',
           'data-sgr-platform-zone': 'true')
      label_width = zone[:label_width]
      rect(zone[:x] + 18, zone[:y] - 8, label_width, 18, rx: 2, fill: 'var(--sgr-paper)',
           'data-sgr-platform-label-mask': 'true')
      text(zone[:display_label], zone[:x] + 28, zone[:y] + 5, class: 'sgr-integration-zone-label')
    end

    def draw_integration_route(route)
      wire = route[:wire]
      stroke, width, dash, marker = case wire.kind
      when :federated then ['var(--sgr-link)', 1.1, '4 3', 'arrow-link']
      when :trigger then ['var(--sgr-muted)', 1, '4 3', 'arrow-open']
      when :serve then ['var(--sgr-accent)', 1.4, nil, 'arrow-accent']
      else ['var(--sgr-muted)', 1.2, nil, 'arrow']
      end
      add %(<path #{attrs('data-sgr-integration-wire': "#{wire.from}-#{wire.to}",
                          'data-sgr-wire-kind': wire.kind, 'data-sgr-route-orthogonal': true,
                          'data-sgr-rounded-bends': true, d: integration_rounded_path(route[:points]),
                          fill: 'none', stroke: stroke, 'stroke-width': width,
                          'stroke-dasharray': dash, 'marker-end': "url(##{@id}-#{marker})")}/>)
      sx, sy = route[:source_port]
      tx, ty = route[:target_port]
      add %(<circle data-sgr-integration-source-port="#{esc(wire.from)}" cx="#{integration_coord(sx)}" cy="#{integration_coord(sy)}" r="1.8" fill="#{stroke}"/>)
      add %(<circle data-sgr-integration-target-port="#{esc(wire.to)}" cx="#{integration_coord(tx)}" cy="#{integration_coord(ty)}" r="1.8" fill="#{stroke}"/>)
    end

    def draw_integration_layer_route(entry)
      sx, sy = entry[:source]
      tx, ty = entry[:target]
      add %(<path #{attrs('data-sgr-layer-boundary-wire': entry[:item].id, 'data-sgr-boundary-target': true,
                          d: "M #{integration_coord(sx)} #{integration_coord(sy)} V #{integration_coord(ty)}",
                          fill: 'none', stroke: 'var(--sgr-accent)', 'stroke-width': 1.2,
                          'stroke-dasharray': '5 4', 'marker-end': "url(##{@id}-arrow-accent)")}/>)
    end

    def draw_integration_side_card(entry)
      item = entry[:item]
      rect(entry[:x], entry[:y], entry[:width], entry[:height], rx: 6,
           class: 'sgr-integration-card sgr-integration-side',
           'data-sgr-integration-endpoint': item.id, 'data-sgr-endpoint-side': entry[:side],
           'data-sgr-endpoint-kind': item.kind)
      draw_integration_icon(item.kind, entry[:x] + 19, entry[:y] + 22)
      title_y = entry[:title_lines].size == 1 ? entry[:y] + 19 : entry[:y] + 15
      entry[:title_lines].each_with_index do |value, index|
        text(value, entry[:x] + 38, title_y + index * 13, class: 'sgr-integration-name',
             'data-sgr-text-lane': 'title')
      end
      text(item.detail, entry[:x] + 38, entry[:y] + 43, class: 'sgr-integration-detail',
           'data-sgr-text-lane': 'detail') if item.detail
      text(item.kind.to_s.tr('_', ' ').upcase, entry[:x] + 10, entry[:y] + 58,
           class: 'sgr-integration-kind', 'letter-spacing': 0.6, 'data-sgr-text-lane': 'kind')
    end

    def draw_integration_component(entry)
      item = entry[:item]
      classes = "sgr-integration-card#{item.focal ? ' sgr-integration-focal' : ''}"
      rect(entry[:x], entry[:y], entry[:width], entry[:height], rx: 6, class: classes,
           'data-sgr-integration-component': item.id, 'data-sgr-platform-band': entry[:band_kind],
           'data-sgr-component-focal': item.focal, 'data-sgr-component-serves': item.serves)
      if entry[:band_kind] == :bar
        entry[:title_lines].each_with_index do |value, index|
          text(value, entry[:x] + 16, entry[:y] + 21 + index * 14,
               class: "sgr-integration-name#{item.focal ? ' sgr-emphasis' : ''}")
        end
        text(item.detail, entry[:x] + 178, entry[:y] + 27, class: 'sgr-integration-detail') if item.detail
        draw_integration_role(item, entry[:x] + entry[:width] - entry[:role_width] - 8, entry[:y] + 8, entry[:role_width])
      else
        draw_integration_role(item, entry[:x] + 8, entry[:y] + 7, entry[:role_width])
        entry[:title_lines].each_with_index do |value, index|
          text(value, entry[:x] + 10, entry[:y] + 37 + index * 13,
               class: "sgr-integration-name#{item.focal ? ' sgr-emphasis' : ''}")
        end
        text(item.detail, entry[:x] + 10, entry[:y] + 64, class: 'sgr-integration-detail') if item.detail
      end
      if item.serves
        text('SERVES', entry[:x] + entry[:width] - 12, entry[:y] + entry[:height] - 9,
             class: 'sgr-integration-role', 'text-anchor': 'end', 'data-sgr-serving-badge': 'true')
      end
    end

    def draw_integration_role(item, x, y, width)
      return unless item.role
      rect(x, y, width, 16, rx: 2, fill: 'var(--sgr-secondary)', stroke: 'var(--sgr-rule)', 'stroke-width': 0.7)
      text(item.role.upcase, x + width / 2.0, y + 11, class: 'sgr-integration-role',
           'text-anchor': 'middle', 'letter-spacing': 0.6)
    end

    def draw_integration_layer_card(entry)
      item = entry[:item]
      rect(entry[:x], entry[:y], entry[:width], entry[:height], rx: 6,
           class: 'sgr-integration-layer', 'data-sgr-layer-service': item.id,
           'data-sgr-layer-service-kind': item.kind)
      draw_integration_icon(item.kind, entry[:x] + 22, entry[:y] + 28)
      text(item.label, entry[:x] + 44, entry[:y] + 19, class: 'sgr-integration-name')
      text(item.detail, entry[:x] + 44, entry[:y] + 35, class: 'sgr-integration-detail') if item.detail
      text(item.kind.to_s.upcase, entry[:x] + entry[:width] - 18, entry[:y] + 49,
           class: 'sgr-integration-kind', 'text-anchor': 'end', 'letter-spacing': 0.6)
    end

    def draw_integration_protocol_label(label)
      x, y, right, bottom = label[:rect]
      rect(x, y, right - x, bottom - y, rx: 3, fill: 'var(--sgr-paper)',
           'data-sgr-protocol-mask': 'true', 'data-sgr-label-gap': label[:gap])
      text(label[:text], (x + right) / 2.0, y + 10, class: 'sgr-integration-protocol',
           'text-anchor': 'middle', 'letter-spacing': 0.7)
    end

    def draw_integration_layer_label(entry)
      left, y, right, bottom = entry[:label][:rect]
      rect(left, y, right - left, bottom - y, rx: 3, fill: 'var(--sgr-paper)',
           'data-sgr-layer-protocol-mask': 'true', 'data-sgr-label-gap': 8)
      text(entry[:item].protocol, (left + right) / 2.0, y + 10, class: 'sgr-integration-protocol',
           'text-anchor': 'middle', 'letter-spacing': 0.7)
    end

    def draw_integration_legend
      x = 40
      y = @s.legend[:y]
      @s.legend[:endpoint_kinds].each do |kind|
        add %(<circle data-sgr-integration-legend-endpoint="#{kind}" cx="#{x + 5}" cy="#{y + 5}" r="4" fill="var(--sgr-secondary)" stroke="var(--sgr-rule)"/>)
        text(kind.to_s.tr('_', ' ').upcase, x + 14, y + 8, class: 'sgr-integration-legend')
        x += Text.width(kind.to_s.tr('_', ' ').upcase, 8, font: :mono) + 40
      end
      x = 40
      @s.legend[:wire_kinds].each do |kind|
        stroke = kind == :serve ? 'var(--sgr-accent)' : kind == :federated ? 'var(--sgr-link)' : 'var(--sgr-muted)'
        dash = %i[federated trigger].include?(kind) ? '4 3' : nil
        add %(<line #{attrs('data-sgr-integration-legend-wire': kind, x1: x, y1: y + 30, x2: x + 24, y2: y + 30,
                            stroke: stroke, 'stroke-width': 1.2, 'stroke-dasharray': dash)}/>)
        text(kind.to_s.upcase, x + 31, y + 33, class: 'sgr-integration-legend')
        x += Text.width(kind.to_s.upcase, 8, font: :mono) + 52
      end
    end

    def draw_integration_icon(kind, x, y)
      add %(<g data-sgr-integration-icon="#{kind}" transform="translate(#{integration_coord(x)} #{integration_coord(y)})" fill="none" stroke="var(--sgr-muted)" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round">)
      paths = {
        database: '<ellipse cx="0" cy="-6" rx="8" ry="3"/><path d="M-8 -6V6c0 4 16 4 16 0V-6M-8 0c0 4 16 4 16 0"/>',
        file_drop: '<path d="M-9 -6h7l3 3h8v11h-18zM0 0v7m-3-3 3 3 3-3"/>',
        mail: '<rect x="-9" y="-6" width="18" height="13" rx="2"/><path d="m-8-4 8 6 8-6"/>',
        legacy: '<rect x="-8" y="-8" width="16" height="16" rx="2"/><path d="M-4-3h8M-4 1h8M-4 5h5"/>',
        analytics: '<path d="M-9 8h18M-6 5v-6h3v6M-1 5v-11h3v11M4 5v-8h3v8"/>',
        web: '<circle cx="0" cy="0" r="8"/><path d="M-8 0h16M0-8c4 4 4 12 0 16M0-8c-4 4-4 12 0 16"/>',
        api: '<path d="M-3-8c-4 0-4 3-4 5v2c0 1-1 2-3 2 2 0 3 1 3 2v2c0 2 0 5 4 5M3-8c4 0 4 3 4 5v2c0 1 1 2 3 2-2 0-3 1-3 2v2c0 2 0 5-4 5"/>',
        identity: '<circle cx="-3" cy="-2" r="4"/><path d="M1 1l8 8M5 5l2-2M7 7l2-2"/>',
        secrets: '<circle cx="-3" cy="-2" r="4"/><path d="M1 1l8 8M5 5l2-2M7 7l2-2"/>',
        observability: '<path d="M-9 7h18M-8 3l4-5 4 3 4-7 5 4"/>',
        backup: '<path d="M-7-5h14v12h-14zM-10-1a10 10 0 0 1 17-6M7-7v5h-5"/>'
      }
      add paths.fetch(kind)
      add '</g>'
    end

    def dp_integration_description
      return @d.description if @d.description
      sources = @d.integration_sources.map { |item| "#{item.label}, #{item.kind.to_s.tr('_', ' ')}#{item.detail ? ": #{item.detail}" : ''}" }.join('; ')
      bands = @d.integration_platform.bands.map do |band|
        contents = band.items.map do |item|
          qualifiers = [item.role && "role #{item.role}", item.detail, item.focal ? 'focal' : nil, item.serves ? 'serving' : nil].compact
          "#{item.label}#{qualifiers.empty? ? '' : ", #{qualifiers.join(', ')}"}"
        end.join('; ')
        "#{band.kind} containing #{contents}"
      end.join('. ')
      consumers = @d.integration_consumers.map { |item| "#{item.label}, #{item.kind}#{item.detail ? ": #{item.detail}" : ''}" }.join('; ')
      layers = @d.integration_layer_services.map { |item| "#{item.label}, #{item.kind}, protocol #{item.protocol}#{item.detail ? ": #{item.detail}" : ''}, scoped to the platform boundary" }.join('; ')
      names = (@d.integration_sources + @d.integration_platform.bands.flat_map(&:items) + @d.integration_consumers).to_h { |item| [item.id, item.label] }
      wires = @d.integration_wires.map { |item| "#{item.kind} wire from #{names.fetch(item.from)} to #{names.fetch(item.to)}#{item.protocol ? ", protocol #{item.protocol}" : ', unlabelled trigger'}" }.join('; ')
      "DP integration. Sources in order: #{sources.empty? ? 'none' : sources}. Platform #{@d.integration_platform.label}, bands in order: #{bands}. " \
        "Consumers in order: #{consumers.empty? ? 'none' : consumers}. Layer services: #{layers.empty? ? 'none' : layers}. Declared wires: #{wires}."
    end

    def integration_rounded_path(points)
      commands = ["M #{integration_coord(points[0][0])} #{integration_coord(points[0][1])}"]
      current = points.first
      points.each_cons(3) do |before_corner, corner, after_corner|
        first = (before_corner[0] - corner[0]).abs + (before_corner[1] - corner[1]).abs
        second = (after_corner[0] - corner[0]).abs + (after_corner[1] - corner[1]).abs
        radius = [8, first / 2.0, second / 2.0].min
        before = [corner[0] + (before_corner[0] <=> corner[0]) * radius, corner[1] + (before_corner[1] <=> corner[1]) * radius]
        after = [corner[0] + (after_corner[0] <=> corner[0]) * radius, corner[1] + (after_corner[1] <=> corner[1]) * radius]
        commands << integration_straight(current, before)
        commands << " Q #{integration_coord(corner[0])} #{integration_coord(corner[1])} #{integration_coord(after[0])} #{integration_coord(after[1])}"
        current = after
      end
      commands << integration_straight(current, points.last)
      commands.join
    end

    def integration_straight(from, to)
      return '' if from == to
      return " H #{integration_coord(to[0])}" if from[1] == to[1]
      return " V #{integration_coord(to[1])}" if from[0] == to[0]
      raise LayoutError, 'DP integration route contains a diagonal segment; split the diagram'
    end

    def integration_coord(value) = value == value.to_i ? value.to_i : value.round(3)
  end
end
