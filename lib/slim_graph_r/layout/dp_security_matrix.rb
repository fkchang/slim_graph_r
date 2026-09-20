# frozen_string_literal: true
module SlimGraphR
  module Layout
    DPSecurityMatrixScene = Struct.new(:width, :height, :component_column, :role_columns, :rows, :legend, keyword_init: true)

    class DPSecurityMatrix
      LEFT = 40
      TOP = 32
      GAP = 12
      ROLE_GAP = 12
      HEADER_HEIGHT = 64
      ROW_HEIGHT = 56
      ROW_GAP = 4
      BOTTOM = 32
      MIN_COMPONENT_WIDTH = 208
      MAX_COMPONENT_WIDTH = 320
      MIN_ROLE_WIDTH = 148
      MAX_ROLE_WIDTH = 220
      LEVEL_LABELS = DPSecurityMatrixDSL::LEVEL_LABELS

      def initialize(diagram) = @d = diagram

      def call
        component_width = measured_component_width
        role_width = measured_role_width
        width = LEFT * 2 + component_width + GAP + @d.security_roles.size * role_width +
                (@d.security_roles.size - 1) * ROLE_GAP
        component_column = { x: LEFT, y: TOP, width: component_width, height: HEADER_HEIGHT }
        role_columns = @d.security_roles.each_with_index.map do |role, index|
          lines = Text.wrap(role.label, role_width - 24, 11)
          raise LayoutError, matrix_error('role label', role.label) if lines.size > (role.code ? 2 : 3)
          {
            role: role, x: LEFT + component_width + GAP + index * (role_width + ROLE_GAP), y: TOP,
            width: role_width, height: HEADER_HEIGHT, lines: lines
          }
        end
        rows = @d.security_components.each_with_index.map do |component, row_index|
          y = TOP + HEADER_HEIGHT + 16 + row_index * (ROW_HEIGHT + ROW_GAP)
          component_lines = Text.wrap(component.label, component_width - (component.hint ? 84 : 24), 11)
          raise LayoutError, matrix_error('component label', component.label) if component_lines.size > 2
          cells = @d.security_roles.each_with_index.map do |role, col_index|
            item = @d.security_permissions.find { |permission| permission.component == component.id && permission.role == role.id }
            lines = Text.wrap(item.label, role_width - 20, 10)
            max_lines = item.note ? 1 : 2
            raise LayoutError, matrix_error('permission label', item.label) if lines.size > max_lines
            note_lines = item.note ? Text.wrap(item.note, role_width - 20, 8) : []
            raise LayoutError, matrix_error('permission note', item.note) if note_lines.size > 2
            { permission: item, x: role_columns[col_index][:x], y: y, width: role_width,
              height: ROW_HEIGHT, lines: lines, note_lines: note_lines }
          end
          { component: component, x: LEFT, y: y, width: component_width, height: ROW_HEIGHT,
            lines: component_lines, cells: cells }
        end
        levels = DPSecurityMatrixDSL::LEVELS.select { |level| @d.security_permissions.any? { |item| item.level == level } }
        legend_width = levels.sum { |level| tracked_width(LEVEL_LABELS.fetch(level).upcase, 9, 1.0) + 42 } +
                       [levels.size - 1, 0].max * 20 + 76
        width = [width, legend_width + LEFT * 2].max
        legend_y = rows.last[:y] + ROW_HEIGHT + 24
        legend = { y: legend_y, levels: levels }
        height = legend_y + 44 + BOTTOM
        DPSecurityMatrixScene.new(width: Text.grid(width), height: Text.grid(height), component_column: component_column,
                                  role_columns: role_columns, rows: rows, legend: legend)
      end

      private

      def measured_component_width
        required = @d.security_components.map do |item|
          Text.width(item.label, 11) + (item.hint ? Text.width(item.hint, 8, font: :mono) + 36 : 24)
        end.max
        required = [required, tracked_width('VS. ROLE', 8, 1.0) + 24, MIN_COMPONENT_WIDTH].max
        raise LayoutError, matrix_error('component label or hint', required) if required > MAX_COMPONENT_WIDTH
        Text.grid(required)
      end

      def measured_role_width
        required = @d.security_roles.map do |role|
          [Text.width(role.label, 11), role.code ? Text.width(role.code, 9, font: :mono) : 0].max + 24
        end.max
        cell_required = @d.security_permissions.map do |item|
          [Text.width(item.label, 10), item.note ? Text.width(item.note, 8) : 0].max + 20
        end.max
        required = [required, cell_required, MIN_ROLE_WIDTH].max
        raise LayoutError, matrix_error('role, code, or permission text', required) if required > MAX_ROLE_WIDTH
        Text.grid(required)
      end

      def tracked_width(value, size, spacing)
        Text.width(value, size, font: :mono) + [value.length - 1, 0].max * spacing
      end

      def matrix_error(kind, value)
        "DP security matrix #{kind} #{value.inspect} does not fit its measured cell; shorten it or split the matrix"
      end
    end
  end
end
