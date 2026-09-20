# frozen_string_literal: true
module SlimGraphR
  class SVG
    MATRIX_LEVEL_CLASS = {
      admin: 'sgr-security-admin', write: 'sgr-security-write', read: 'sgr-security-read',
      deny: 'sgr-security-deny', unknown: 'sgr-security-unknown'
    }.freeze

    def draw_dp_security_matrix
      header = @s.component_column
      rect(header[:x], header[:y], header[:width], header[:height], rx: 6,
           fill: 'var(--sgr-secondary)', stroke: 'var(--sgr-rule)', 'stroke-width': 1)
      text('COMPONENT', header[:x] + 12, header[:y] + 26, class: 'sgr-security-eyebrow')
      text('VS. ROLE', header[:x] + 12, header[:y] + 45, class: 'sgr-security-subtle')
      @s.role_columns.each do |column|
        rect(column[:x], column[:y], column[:width], column[:height], rx: 6,
             fill: 'var(--sgr-ink)', stroke: 'var(--sgr-ink)', 'data-security-role': column[:role].id)
        line_y = column[:role].code ? column[:y] + 22 : column[:y] + 27
        column[:lines].each_with_index do |value, index|
          text(value, column[:x] + column[:width] / 2.0, line_y + index * 14,
               class: 'sgr-security-role', 'text-anchor': 'middle')
        end
        if column[:role].code
          text(column[:role].code, column[:x] + column[:width] / 2.0, column[:y] + 53,
               class: 'sgr-security-role-code', 'text-anchor': 'middle')
        end
      end
      @s.rows.each do |row|
        rect(row[:x], row[:y], row[:width], row[:height], rx: 4,
             fill: 'var(--sgr-paper)', stroke: 'var(--sgr-rule)', 'stroke-width': 1,
             'data-security-component': row[:component].id)
        start_y = row[:y] + (row[:lines].size == 1 ? 33 : 25)
        row[:lines].each_with_index do |value, index|
          text(value, row[:x] + 12, start_y + index * 14, class: 'sgr-security-component')
        end
        if row[:component].hint
          text(row[:component].hint, row[:x] + row[:width] - 12, row[:y] + 33,
               class: 'sgr-security-hint', 'text-anchor': 'end')
        end
        row[:cells].each { |cell| draw_security_cell(cell) }
      end
      draw_security_legend
    end

    def draw_security_cell(cell)
      item = cell[:permission]
      klass = MATRIX_LEVEL_CLASS.fetch(item.level)
      classes = "sgr-security-cell #{klass}#{item.focal ? ' sgr-security-focal' : ''}"
      rect(cell[:x], cell[:y], cell[:width], cell[:height], rx: 4, class: classes,
           'data-security-cell': "#{item.component}:#{item.role}", 'data-security-level': item.level,
           'data-security-focal': item.focal ? 'true' : nil)
      if item.note
        text(cell[:lines].first, cell[:x] + cell[:width] / 2.0, cell[:y] + 21,
             class: 'sgr-security-value sgr-security-focal-value', 'text-anchor': 'middle')
        cell[:note_lines].each_with_index do |value, index|
          text(value, cell[:x] + cell[:width] / 2.0, cell[:y] + 37 + index * 11,
               class: 'sgr-security-note', 'text-anchor': 'middle')
        end
      else
        start_y = cell[:y] + (cell[:lines].size == 1 ? 33 : 26)
        cell[:lines].each_with_index do |value, index|
          text(value, cell[:x] + cell[:width] / 2.0, start_y + index * 14,
               class: "sgr-security-value#{item.focal ? ' sgr-security-focal-value' : ''}", 'text-anchor': 'middle')
        end
      end
    end

    def draw_security_legend
      y = @s.legend[:y]
      rect(40, y, @s.width - 80, 1, fill: 'var(--sgr-rule)')
      text('LEGEND', 40, y + 25, class: 'sgr-security-eyebrow')
      x = 116
      @s.legend[:levels].each do |level|
        label = DPSecurityMatrixDSL::LEVEL_LABELS.fetch(level).upcase
        width = Text.width(label, 9, font: :mono) + 42
        rect(x, y + 13, 16, 14, rx: 2, class: "sgr-security-cell #{MATRIX_LEVEL_CLASS.fetch(level)}",
             'data-security-legend-level': level)
        text(label, x + 24, y + 24, class: 'sgr-security-legend')
        x += width + 20
      end
    end

    def dp_security_matrix_description
      return @d.description if @d.description
      roles = @d.security_roles.map { |item| "#{item.label}#{item.code ? ", code #{item.code}" : ', no code recorded'}" }.join('; ')
      components = @d.security_components.map { |item| "#{item.label}#{item.hint ? ", hint #{item.hint}" : ', no hint recorded'}" }.join('; ')
      role_names = @d.security_roles.to_h { |item| [item.id, item.label] }
      component_names = @d.security_components.to_h { |item| [item.id, item.label] }
      permissions = @d.security_permissions.map do |item|
        detail = "#{component_names.fetch(item.component)} for #{role_names.fetch(item.role)}: #{item.label}, explicit #{item.level}"
        detail += ", focal note #{item.note}" if item.note
        detail += ', focal' if item.focal && !item.note
        detail
      end.join('; ')
      "DP security matrix. Roles in order: #{roles}. Components in order: #{components}. Recorded permissions: #{permissions}."
    end
  end
end
