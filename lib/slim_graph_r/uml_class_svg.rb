# frozen_string_literal: true
module SlimGraphR
  class SVG
    def uml_marker_definitions
      <<~SVG.chomp
        <marker id="#{@id}-inheritance-triangle" viewBox="0 0 14 12" refX="13" refY="6" markerWidth="14" markerHeight="12" orient="auto" markerUnits="userSpaceOnUse"><path d="M 1 1 L 13 6 L 1 11 Z" fill="var(--sgr-paper)" stroke="var(--sgr-muted)" stroke-width="1.2"/></marker>
        <marker id="#{@id}-realization-triangle" viewBox="0 0 14 12" refX="13" refY="6" markerWidth="14" markerHeight="12" orient="auto" markerUnits="userSpaceOnUse"><path d="M 1 1 L 13 6 L 1 11 Z" fill="var(--sgr-paper)" stroke="var(--sgr-muted)" stroke-width="1.2"/></marker>
        <marker id="#{@id}-inheritance-triangle-accent" viewBox="0 0 14 12" refX="13" refY="6" markerWidth="14" markerHeight="12" orient="auto" markerUnits="userSpaceOnUse"><path d="M 1 1 L 13 6 L 1 11 Z" fill="var(--sgr-paper)" stroke="var(--sgr-accent)" stroke-width="1.2"/></marker>
        <marker id="#{@id}-realization-triangle-accent" viewBox="0 0 14 12" refX="13" refY="6" markerWidth="14" markerHeight="12" orient="auto" markerUnits="userSpaceOnUse"><path d="M 1 1 L 13 6 L 1 11 Z" fill="var(--sgr-paper)" stroke="var(--sgr-accent)" stroke-width="1.2"/></marker>
        <marker id="#{@id}-composition-diamond" viewBox="0 0 14 10" refX="13" refY="5" markerWidth="14" markerHeight="10" orient="auto-start-reverse" markerUnits="userSpaceOnUse"><path d="M 1 5 L 7 1 L 13 5 L 7 9 Z" fill="var(--sgr-muted)" stroke="var(--sgr-muted)" stroke-width="1"/></marker>
        <marker id="#{@id}-aggregation-diamond" viewBox="0 0 14 10" refX="13" refY="5" markerWidth="14" markerHeight="10" orient="auto-start-reverse" markerUnits="userSpaceOnUse"><path d="M 1 5 L 7 1 L 13 5 L 7 9 Z" fill="var(--sgr-paper)" stroke="var(--sgr-muted)" stroke-width="1"/></marker>
        <marker id="#{@id}-dependency-arrow" viewBox="0 0 9 8" refX="8" refY="4" markerWidth="9" markerHeight="8" orient="auto" markerUnits="userSpaceOnUse"><path d="M 1 1 L 8 4 L 1 7" fill="none" stroke="var(--sgr-muted)" stroke-width="1.2"/></marker>
      SVG
    end

    def draw_uml_class
      @s.routes.each { |route| draw_uml_relation(route) }
      @s.boxes.each { |box| draw_uml_class_card(box) }
      @s.routes.each do |route|
        draw_uml_multiplicity(route.from_label)
        draw_uml_multiplicity(route.to_label)
        draw_uml_relation_label(route.label)
      end
      draw_uml_legend
    end

    def draw_uml_relation(route)
      relation = route.relation
      attrs = {
        d: rounded_orthogonal_path(route.points), fill: 'none', stroke: uml_relation_color(relation),
        'stroke-width': 1.2, 'data-sgr-relation-kind': relation.kind,
        'data-sgr-relation-from': relation.from, 'data-sgr-relation-to': relation.to
      }
      attrs['stroke-dasharray'] = '5,4' if relation.kind == :realization
      attrs['stroke-dasharray'] = '4,3' if relation.kind == :dependency
      case relation.kind
      when :inheritance
        attrs['marker-end'] = "url(##{@id}-inheritance-triangle#{uml_relation_accent?(relation) ? '-accent' : ''})"
      when :realization
        attrs['marker-end'] = "url(##{@id}-realization-triangle#{uml_relation_accent?(relation) ? '-accent' : ''})"
      when :dependency
        attrs['marker-end'] = "url(##{@id}-dependency-arrow)"
      when :composition, :aggregation
        owner_end = relation.owner == relation.from ? :from : :to
        attrs['data-sgr-owner'] = relation.owner
        attrs['data-sgr-owner-end'] = owner_end
        attrs[owner_end == :from ? 'marker-start' : 'marker-end'] = "url(##{@id}-#{relation.kind}-diamond)"
      end
      add "<path #{attrs.map { |key, value| %(#{key}=\"#{esc(value)}\") }.join(' ')}/>"
      [[:from, route.from_port], [:to, route.to_port]].each do |endpoint, port|
        add %(<circle cx="#{er_num(port[:point][0])}" cy="#{er_num(port[:point][1])}" r="0" fill="none" data-sgr-uml-port="#{endpoint}" data-sgr-class-id="#{esc(port[:class_id])}" data-sgr-side="#{port[:side]}"/>)
      end
    end

    def uml_relation_color(relation)
      uml_relation_accent?(relation) ? 'var(--sgr-accent)' : 'var(--sgr-muted)'
    end

    def uml_relation_accent?(relation)
      target = @d.classes.find { |item| item.id == relation.to }
      target&.focal && %i[inheritance realization].include?(relation.kind)
    end

    def draw_uml_class_card(box)
      item = box.class_record
      focal = item.focal
      rect(box.x, box.y, box.width, box.height, rx: 6, fill: focal ? 'var(--sgr-tint)' : 'var(--sgr-paper)',
           stroke: focal ? 'var(--sgr-accent)' : 'var(--sgr-ink)', 'stroke-width': 1,
           'data-sgr-uml-class': item.id, 'data-sgr-uml-kind': item.kind)
      if item.kind == :interface
        text('«interface»', box.x + box.width / 2.0, box.y + 16, class: 'sgr-uml-stereotype', 'text-anchor': 'middle')
        name_y = box.y + 36
      else
        name_y = box.y + 23
      end
      name_class = ['sgr-uml-name', ('sgr-uml-abstract' if item.kind == :abstract_class), ('sgr-uml-focal' if focal)].compact.join(' ')
      box.name_lines.each_with_index do |line_value, index|
        text(line_value, box.x + box.width / 2.0, name_y + index * Layout::UMLClass::MEMBER_ROW_HEIGHT,
             class: name_class, 'text-anchor': 'middle')
      end
      draw_uml_compartment(box, box.attribute_rect, box.attribute_rows, :attributes)
      draw_uml_compartment(box, box.operation_rect, box.operation_rows, :operations)
    end

    def draw_uml_compartment(box, bounds, rows, kind)
      return unless bounds
      x, y, right, bottom = bounds
      rect(x, y, right - x, bottom - y, fill: 'var(--sgr-paper)', 'fill-opacity': 0.001,
           'data-sgr-compartment': kind)
      line(box.x, y, box.x + box.width, y, 'var(--sgr-rule)')
      cursor_y = y + 18
      rows.each do |row|
        row[:lines].each_with_index do |line_value, index|
          text(line_value, x + 12, cursor_y + index * Layout::UMLClass::MEMBER_ROW_HEIGHT,
               class: 'sgr-uml-member', 'data-sgr-member': row[:value])
        end
        cursor_y += row[:height]
      end
    end

    def draw_uml_multiplicity(label)
      return unless label
      rect(label[:x] - label[:width] / 2.0, label[:y] - label[:height] / 2.0, label[:width], label[:height],
           rx: 2, fill: 'var(--sgr-paper)', 'data-sgr-multiplicity-mask': 'true')
      text(label[:text], label[:x], label[:y] + 3, class: 'sgr-uml-multiplicity', 'text-anchor': 'middle',
           'data-sgr-multiplicity-end': label[:endpoint])
    end

    def draw_uml_relation_label(label)
      return unless label
      rect(label[:x] - label[:width] / 2.0, label[:y] - label[:height] / 2.0, label[:width], label[:height],
           rx: 2, fill: 'var(--sgr-paper)', 'data-sgr-relation-label-mask': 'true')
      text(label[:text], label[:x], label[:y] + 3, class: 'sgr-uml-relation-label', 'text-anchor': 'middle',
           'data-sgr-relation-label': label[:text])
    end

    def draw_uml_legend
      legend = @s.legend
      line(legend[:x], legend[:y] - 18, legend[:x] + legend[:width], legend[:y] - 18, 'var(--sgr-rule)')
      kinds = %i[inheritance realization composition aggregation association dependency]
      column_width = legend[:width] / 3.0
      kinds.each_with_index do |kind, index|
        column = index % 3
        row = index / 3
        x = legend[:x] + column * column_width
        y = legend[:y] + row * 40
        attrs = { 'data-sgr-legend-kind': kind, x1: x, y1: y, x2: x + 44, y2: y,
                  stroke: 'var(--sgr-muted)', 'stroke-width': 1.2 }
        attrs['stroke-dasharray'] = '5,4' if kind == :realization
        attrs['stroke-dasharray'] = '4,3' if kind == :dependency
        attrs['marker-end'] = "url(##{@id}-#{kind}-triangle)" if %i[inheritance realization].include?(kind)
        attrs['marker-start'] = "url(##{@id}-#{kind}-diamond)" if %i[composition aggregation].include?(kind)
        attrs['marker-end'] = "url(##{@id}-dependency-arrow)" if kind == :dependency
        add "<line #{attrs.map { |key, value| %(#{key}=\"#{esc(value)}\") }.join(' ')}/>"
        text(kind.to_s.tr('_', ' ').capitalize, x + 56, y + 3, class: 'sgr-uml-legend')
      end
    end

    def uml_class_description
      return @d.description if @d.description
      classes = @d.classes.map do |item|
        prefix = item.kind == :interface ? 'Interface' : item.kind == :abstract_class ? 'Abstract class' : 'Class'
        members = []
        members << "attributes #{item.attributes.join(', ')}" unless item.attributes.empty?
        members << "operations #{item.operations.join(', ')}" unless item.operations.empty?
        "#{prefix} #{item.label}#{item.focal ? ', focal' : ''}#{members.empty? ? '' : ": #{members.join('; ')}"}."
      end.join(' ')
      relations = @d.relations.map do |item|
        from = @d.classes.find { |candidate| candidate.id == item.from }.label
        to = @d.classes.find { |candidate| candidate.id == item.to }.label
        case item.kind
        when :inheritance then "#{from} inherits #{to}."
        when :realization then "#{from} realizes #{to}."
        when :composition, :aggregation then "#{from} and #{to} have a #{item.kind} relation owned by #{@d.classes.find { |candidate| candidate.id == item.owner }.label}."
        when :association then "#{from} #{item.from_multiplicity} associates with #{to} #{item.to_multiplicity}."
        else "#{from} depends on #{to}."
        end
        .then { |description| item.label ? "#{description.chomp('.')} (#{item.label})." : description }
      end.join(' ')
      "UML class diagram. #{classes} #{relations}"
    end
  end
end
