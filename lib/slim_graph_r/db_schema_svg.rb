# frozen_string_literal: true
module SlimGraphR
  class SVG
    def draw_db_schema
      @s.schema_groups.each { |group| draw_database_schema_group(group) }
      @s.routes.each { |route| draw_database_foreign_key(route) }
      @s.boxes.each { |box| draw_database_table(box) }
      @s.routes.each { |route| draw_database_action_label(route) }
    end

    def draw_database_schema_group(group)
      x, y, right, bottom = group[:rect]
      rect(x, y, right - x, bottom - y, rx: 8, fill: 'var(--sgr-ink)', 'fill-opacity': 0.02,
           stroke: 'var(--sgr-ink)', 'stroke-opacity': 0.20, 'stroke-dasharray': '4 4',
           'data-sgr-db-schema': group[:schema])
      text(group[:schema].upcase, x + 12, y + 15, class: 'sgr-db-schema-label')
    end

    def draw_database_foreign_key(route)
      fk = route.foreign_key
      cascade = fk.on_delete == :cascade
      add %(<path d="#{rounded_orthogonal_path(route.points)}" fill="none" stroke="var(--sgr-#{cascade ? 'accent' : 'muted'})" stroke-width="1.2" data-sgr-db-foreign-key="#{esc(fk.from_table)}:#{esc(fk.from_column)}-#{esc(fk.to_table)}:#{esc(fk.to_column)}" data-sgr-db-action="#{fk.on_delete}"/> )
      [[:source, route.from_port], [:target, route.to_port]].each do |kind, port|
        add %(<circle cx="#{er_num(port[:point][0])}" cy="#{er_num(port[:point][1])}" r="0" fill="none" data-sgr-db-port="#{kind}" data-sgr-db-table="#{esc(port[:table])}" data-sgr-db-column-id="#{esc(port[:column])}" data-sgr-db-side="#{port[:side]}"/>)
      end
    end

    def draw_database_table(box)
      table = box.table
      cascade = @d.foreign_keys.any? { |fk| fk.from_table == table.id && fk.on_delete == :cascade }
      rect(box.x, box.y, box.width, box.height, rx: 6, fill: 'var(--sgr-paper)', stroke: 'var(--sgr-ink)',
           'stroke-width': 1, 'data-sgr-db-table': table.id)
      rect(box.x, box.y, box.width, 32, rx: 6, fill: cascade ? 'var(--sgr-tint)' : 'var(--sgr-secondary)',
           'data-sgr-db-table-header': table.id, 'data-sgr-db-cascade-header': cascade ? 'true' : nil)
      rect(box.x, box.y + 26, box.width, 6, fill: cascade ? 'var(--sgr-tint)' : 'var(--sgr-secondary)')
      tag_width = Text.width('TABLE', Layout::DatabaseSchema::METADATA_TEXT_SIZE, font: :mono) + 14
      rect(box.x + 10, box.y + 8, tag_width, 16, rx: 2, fill: 'var(--sgr-paper)', stroke: 'var(--sgr-rule)', 'stroke-width': 0.8)
      text('TABLE', box.x + 10 + tag_width / 2.0, box.y + 19, class: 'sgr-db-tag', 'text-anchor': 'middle')
      text(table.label, box.x + box.width - 10, box.y + 21, class: 'sgr-db-table-name', 'text-anchor': 'end')
      box.column_rows.each_with_index do |row, index|
        column = row[:column]
        x, y, right, bottom = row[:rect]
        rect(x, y, right - x, bottom - y, fill: 'var(--sgr-ink)', 'fill-opacity': index.odd? ? 0.02 : 0,
             'data-sgr-db-column': "#{table.id}:#{column.id}")
        text(column.label, x + 10, y + 16, class: 'sgr-db-column-name')
        type_width = Text.width(column.sql_type, Layout::DatabaseSchema::METADATA_TEXT_SIZE, font: :mono)
        text(column.sql_type, right - 10, y + 16, class: 'sgr-db-sql-type', 'text-anchor': 'end')
        chip_x = [x + 20 + Text.width(column.label, Layout::DatabaseSchema::PRIMARY_TEXT_SIZE), right - 18 - type_width - column.constraints.sum { |value| Text.width(value.to_s.upcase, Layout::DatabaseSchema::METADATA_TEXT_SIZE, font: :mono) + 13 }].max
        column.constraints.each do |constraint|
          label = constraint.to_s.upcase
          chip_width = Text.width(label, Layout::DatabaseSchema::METADATA_TEXT_SIZE, font: :mono) + 9
          rect(chip_x, y + 5, chip_width, 14, rx: 2, fill: 'var(--sgr-secondary)', stroke: 'var(--sgr-rule)', 'stroke-width': 0.6,
               'data-sgr-db-constraint': constraint)
          text(label, chip_x + chip_width / 2.0, y + 15, class: 'sgr-db-constraint', 'text-anchor': 'middle')
          chip_x += chip_width + 4
        end
      end
      if (row = box.overflow_row)
        x, y, right, bottom = row[:rect]
        rect(x, y, right - x, bottom - y, fill: 'var(--sgr-secondary)', 'fill-opacity': 0.45,
             'data-sgr-db-overflow-count': row[:overflow].count)
        text("+ #{row[:overflow].count} more columns", x + 10, y + 16, class: 'sgr-db-overflow')
      end
      unless box.index_rows.empty?
        divider = box.overflow_row ? box.overflow_row[:rect][3] : box.column_rows.last[:rect][3]
        line(box.x, divider, box.x + box.width, divider, 'var(--sgr-rule)')
        text('INDEXES', box.x + 10, divider + 15, class: 'sgr-db-index-eyebrow')
        box.index_rows.each { |row| text(row[:name], row[:x], row[:y], class: 'sgr-db-index') }
      end
    end

    def draw_database_action_label(route)
      label = route.label_box
      cascade = route.foreign_key.on_delete == :cascade
      rect(label[:x] - label[:width] / 2.0, label[:y] - label[:height] / 2.0, label[:width], label[:height],
           rx: 2, fill: 'var(--sgr-paper)', 'data-sgr-db-action-mask': 'true', 'data-sgr-db-line-gap': 8)
      text(label[:text], label[:x], label[:y] + 3, class: "sgr-db-action#{cascade ? ' sgr-db-action-cascade' : ''}",
           'text-anchor': 'middle')
    end

    def db_schema_description
      return @d.description if @d.description
      tables = @d.tables.map do |table|
        columns = table.columns.map do |column|
          constraints = column.constraints.empty? ? 'no declared constraints' : "constraints #{column.constraints.map(&:upcase).join(', ')}"
          "#{column.label} #{column.sql_type}, #{constraints}"
        end.join('; ')
        indexes = table.indexes.empty? ? 'no named indexes' : "indexes #{table.indexes.join(', ')}"
        overflow = table.overflow ? "; plus #{table.overflow.count} more columns explicitly omitted from this view" : ''
        "#{table.schema ? "#{table.schema}." : ''}#{table.label}: #{columns}#{overflow}; #{indexes}"
      end.join('. ')
      keys = @d.foreign_keys.map do |fk|
        "#{fk.from_table}.#{fk.from_column} references #{fk.to_table}.#{fk.to_column}, ON DELETE #{fk.on_delete.to_s.tr('_', ' ').upcase}"
      end.join('; ')
      "Database schema diagram. Tables in order: #{tables}. Foreign keys: #{keys}."
    end
  end
end
