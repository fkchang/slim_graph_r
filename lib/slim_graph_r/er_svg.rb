# frozen_string_literal: true
module SlimGraphR
  class SVG
    def draw_er
      @s.routes.each { |route| draw_er_route(route) }
      @s.boxes.each { |box| draw_er_box(box) }
      @s.routes.each do |route|
        draw_er_cardinality(route.from_port, route.relationship.from_cardinality, 'from', route.relationship)
        draw_er_cardinality(route.to_port, route.relationship.to_cardinality, 'to', route.relationship)
        draw_er_label(route.label_box) if route.label_box
      end
    end

    def draw_er_route(route)
      d = rounded_orthogonal_path(route.points)
      add %(<path d="#{d}" fill="none" stroke="var(--sgr-muted)" stroke-width="1.2" data-er-relationship="#{esc(route.relationship.from)}:#{esc(route.relationship.to)}"/>)
      [route.from_port, route.to_port].each do |port|
        coordinate = %i[left right].include?(port[:side]) ? port[:point][1] : port[:point][0]
        add %(<circle cx="#{er_num(port[:point][0])}" cy="#{er_num(port[:point][1])}" r="0" fill="none" data-er-port="true" data-er-relationship="#{esc(route.relationship.from)}:#{esc(route.relationship.to)}" data-er-entity="#{esc(port[:entity])}" data-er-side="#{port[:side]}" data-er-coordinate="#{er_num(coordinate)}"/>)
      end
    end

    def rounded_orthogonal_path(points)
      return "M #{er_num(points[0][0])} #{er_num(points[0][1])} L #{er_num(points[1][0])} #{er_num(points[1][1])}" if points.size == 2
      output = ["M #{er_num(points[0][0])} #{er_num(points[0][1])}"]
      cursor = points[0]
      (1...(points.size - 1)).each do |index|
        previous, current, following = points[index - 1], points[index], points[index + 1]
        incoming = [(current[0] - previous[0]), (current[1] - previous[1])]
        outgoing = [(following[0] - current[0]), (following[1] - current[1])]
        radius = [8.0, incoming.map(&:abs).max / 2.0, outgoing.map(&:abs).max / 2.0].min
        before = [current[0] - (incoming[0] <=> 0) * radius, current[1] - (incoming[1] <=> 0) * radius]
        after = [current[0] + (outgoing[0] <=> 0) * radius, current[1] + (outgoing[1] <=> 0) * radius]
        output << " L #{er_num(before[0])} #{er_num(before[1])}" unless before == cursor
        output << " Q #{er_num(current[0])} #{er_num(current[1])} #{er_num(after[0])} #{er_num(after[1])}"
        cursor = after
      end
      output << " L #{er_num(points[-1][0])} #{er_num(points[-1][1])}" unless points[-1] == cursor
      output.join
    end

    def draw_er_box(box)
      entity = box.entity
      fill = entity.focal ? 'var(--sgr-tint)' : 'var(--sgr-paper)'
      stroke = entity.focal ? 'var(--sgr-accent)' : 'var(--sgr-ink)'
      rect(box.x, box.y, box.width, box.height, rx: 6, fill: fill, stroke: stroke,
           'stroke-width': entity.focal ? 1.5 : 1, 'data-er-entity': entity.id)
      rect(box.x, box.y + 28, box.width, 1, fill: 'var(--sgr-rule)')
      text(entity.kind.to_s.tr('_', ' ').upcase, box.x + 10, box.y + 18, class: 'sgr-er-tag', 'data-er-entity-kind': entity.kind)
      text(entity.label, box.x + box.width - 10, box.y + 19, class: "sgr-er-name#{entity.focal ? ' sgr-er-focal' : ''}", 'text-anchor': 'end')
      y = box.y + 41
      box.field_rows.each do |row|
        glyph = { primary: '#', foreign: '→' }[row[:field].key]
        text(glyph, box.x + 12, y + 11, class: 'sgr-er-key', 'data-er-field-key': row[:field].key) if glyph
        row[:lines].each_with_index do |value, index|
          text(value, box.x + 12 + (glyph ? 18 : 0), y + 11 + index * 20, class: 'sgr-er-field', 'data-er-field': row[:field].id)
        end
        y += row[:height]
      end
    end

    def draw_er_cardinality(port, value, endpoint, relationship)
      x, y = port[:point]
      width = Text.width(value, 8, font: :mono) + 8
      height = 14
      edge_gap = 8
      case port[:side]
      when :left then x -= edge_gap + width / 2.0
      when :right then x += edge_gap + width / 2.0
      when :top then y -= edge_gap + height / 2.0
      when :bottom then y += edge_gap + height / 2.0
      end
      rect(x - width / 2.0, y - height / 2.0, width, height, rx: 2, fill: 'var(--sgr-paper)',
           'data-er-cardinality-mask': endpoint, 'data-er-mask-gap': edge_gap,
           'data-er-relationship': "#{relationship.from}:#{relationship.to}", 'data-er-entity': port[:entity])
      text(value, x, y + 1, class: 'sgr-er-cardinality', 'text-anchor': 'middle',
           'data-er-cardinality': value, 'data-er-endpoint': endpoint, 'data-er-entity': port[:entity],
           'data-er-relationship': "#{relationship.from}:#{relationship.to}",
           'data-er-anchor-x': er_num(x), 'data-er-anchor-y': er_num(y))
    end

    def draw_er_label(label)
      rect(label[:x] - label[:width] / 2.0, label[:y] - label[:height] / 2.0,
           label[:width], label[:height], rx: 3, fill: 'var(--sgr-paper)',
           'data-er-label-mask': 'true', 'data-er-line-gap': 8)
      text(label[:text], label[:x], label[:y] + 4, class: 'sgr-er-label', 'text-anchor': 'middle')
    end

    def er_description
      return @d.description if @d.description
      entities = @d.entities.map do |entity|
        fields = entity.fields.map do |field|
          metadata = [field.type && "type #{field.type}", field.qualifier && "qualifier #{field.qualifier}"].compact.join(', ')
          "#{field.label}#{field.key ? ", declared #{field.key} key" : ', no key classification'}#{metadata.empty? ? '' : ", #{metadata}"}"
        end.join('; ')
        "#{entity.label}, #{entity.kind.to_s.tr('_', ' ')}#{entity.focal ? ', focal' : ''}, fields: #{fields}"
      end.join('. ')
      relationships = @d.relationships.map do |item|
        from = @d.entities.find { |entity| entity.id == item.from }.label
        to = @d.entities.find { |entity| entity.id == item.to }.label
        "#{from} #{item.from_cardinality} to #{item.to_cardinality} #{to}#{item.label ? ", labelled #{item.label}" : ', unlabelled'}"
      end.join('; ')
      "Entity relationship diagram. Entities in order: #{entities}. Authored relationships: #{relationships}."
    end

    def er_num(value) = value.round(2)
  end
end
