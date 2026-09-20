# frozen_string_literal: true
module SlimGraphR
  DatabaseColumn = Struct.new(:id, :label, :sql_type, :constraints, keyword_init: true)
  DatabaseOverflow = Struct.new(:count, keyword_init: true)
  DatabaseTable = Struct.new(:id, :label, :schema, :columns, :indexes, :overflow, keyword_init: true)
  DatabaseForeignKey = Struct.new(:from_table, :from_column, :to_table, :to_column, :on_delete, keyword_init: true)

  module DatabaseSchemaDSL
    DB_UNSET = Object.new.freeze
    CONSTRAINTS = %i[pk fk uq nn].freeze
    DELETE_ACTIONS = %i[cascade restrict set_null no_action].freeze

    attr_reader :tables, :foreign_keys

    def initialize(...)
      @tables = []
      @foreign_keys = []
      @current_database_table = nil
      super
    end

    def table(id, label = DB_UNSET, schema: DB_UNSET, **options, &block)
      raise Error, 'table is available only in a database-schema diagram' unless type == :db_schema
      raise Error, 'Database tables cannot be nested' if @current_database_table
      raise Error, "Unknown database table options: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'Table label is required and must not be blank' if label.equal?(DB_UNSET)
      item = DatabaseTable.new(
        id: database_text(id, 'Table ID'), label: database_text(label, 'Table label'),
        schema: schema.equal?(DB_UNSET) ? nil : database_text(schema, 'Table schema'), columns: [], indexes: [], overflow: nil
      )
      @tables << item
      previous = @current_database_table
      @current_database_table = item
      instance_eval(&block) if block
      item
    rescue Exception
      @tables.delete(item) if defined?(item) && item
      raise
    ensure
      @current_database_table = previous if defined?(previous)
    end

    def column(id, label = DB_UNSET, sql_type: DB_UNSET, constraints: [], **options, &block)
      unless type == :db_schema
        if !sql_type.equal?(DB_UNSET) || !constraints.empty?
          raise Error, 'sql_type and constraints are available only in a database-schema column'
        end
        arguments = [id]
        arguments << label unless label.equal?(DB_UNSET)
        return super(*arguments, **options, &block)
      end
      raise Error, 'A database column must be declared inside a table' unless @current_database_table
      raise Error, "Unknown database column options: #{options.keys.join(', ')}" unless options.empty?
      raise Error, 'Column label is required and must not be blank' if label.equal?(DB_UNSET)
      raise Error, 'Column SQL type is required and must not be blank' if sql_type.equal?(DB_UNSET)
      unless constraints.is_a?(Array) && constraints.all? { |value| value.is_a?(String) || value.is_a?(Symbol) }
        raise Error, 'Column constraints must be an array containing pk, fk, uq, or nn'
      end
      cleaned = constraints.map(&:to_sym)
      unless cleaned.uniq == cleaned && (cleaned - CONSTRAINTS).empty?
        raise Error, 'Column constraints must be unique values from pk, fk, uq, and nn'
      end
      @current_database_table.columns << DatabaseColumn.new(
        id: database_text(id, 'Column ID'), label: database_text(label, 'Column label'),
        sql_type: database_text(sql_type, 'Column SQL type'), constraints: cleaned
      )
    end

    def index(name)
      raise Error, 'index is available only in a database-schema diagram' unless type == :db_schema
      raise Error, 'A database index must be declared inside a table' unless @current_database_table
      @current_database_table.indexes << database_text(name, 'Index name')
    end

    def overflow_columns(count)
      raise Error, 'overflow_columns is available only in a database-schema diagram' unless type == :db_schema
      raise Error, 'An overflow count must be declared inside a table' unless @current_database_table
      raise Error, 'A table accepts one explicit overflow count' if @current_database_table.overflow
      unless count.is_a?(Integer) && count.between?(1, 99)
        raise Error, 'Overflow column count must be an integer from 1 to 99'
      end
      @current_database_table.overflow = DatabaseOverflow.new(count: count)
    end

    def foreign_key(from_table, from_column, references:, on_delete:, **options)
      raise Error, 'foreign_key is available only in a database-schema diagram' unless type == :db_schema
      raise Error, 'A foreign key must be declared outside table blocks' if @current_database_table
      raise Error, "Unknown database foreign-key options: #{options.keys.join(', ')}" unless options.empty?
      unless references.is_a?(Array) && references.size == 2
        raise Error, 'Foreign key references must be [table, column]'
      end
      action = on_delete.to_sym
      unless DELETE_ACTIONS.include?(action)
        raise Error, "Foreign key on_delete must be one of #{DELETE_ACTIONS.join(', ')}"
      end
      item = DatabaseForeignKey.new(
        from_table: database_text(from_table, 'Foreign key source table'),
        from_column: database_text(from_column, 'Foreign key source column'),
        to_table: database_text(references[0], 'Foreign key target table'),
        to_column: database_text(references[1], 'Foreign key target column'), on_delete: action
      )
      if @foreign_keys.any? { |fk| fk.to_h == item.to_h }
        raise Error, 'Duplicate database foreign key'
      end
      @foreign_keys << item
    rescue NoMethodError
      raise Error, "Foreign key on_delete must be one of #{DELETE_ACTIONS.join(', ')}"
    end

    def node(...)
      raise Error, 'Database-schema diagrams use dedicated database-schema table and column records' if type == :db_schema
      super
    end

    def edge(...)
      raise Error, 'Database-schema diagrams use foreign_key with exact column endpoints' if type == :db_schema
      super
    end

    def flow(...)
      raise Error, 'Database-schema diagrams use foreign_key with exact column endpoints' if type == :db_schema
      super
    end

    def group(...)
      raise Error, 'A database-schema diagram does not accept generic groups' if type == :db_schema
      super
    end

    private

    def database_text(value, name)
      raise Error, "#{name} must be a String or Symbol" unless value.is_a?(String) || value.is_a?(Symbol)
      clean = Text.clean(value)
      raise Error, "#{name} is required and must not be blank" if clean.strip.empty?
      clean
    end

    def validate_db_schema!
      unless nodes.empty? && edges.empty? && groups.empty? && events.empty? && rules.empty? && states.empty? &&
             transitions.empty? && zones.empty? && phases.empty? && crosscuts.empty?
        raise Error, 'Database-schema diagrams accept only dedicated database-schema records'
      end
      raise Error, 'Database-schema diagrams require two to five tables' unless tables.size.between?(2, 5)
      raise Error, 'Database table IDs must be unique' unless tables.map(&:id).uniq.size == tables.size
      tables.each do |item|
        raise Error, "Database table #{item.id} requires one to eight visible columns" unless item.columns.size.between?(1, 8)
        unless item.columns.map(&:id).uniq.size == item.columns.size
          raise Error, "Database column IDs must be unique within table #{item.id}"
        end
        raise Error, "Database table #{item.id} allows zero to three named indexes" unless item.indexes.size <= 3
        raise Error, "Database index names must be unique within table #{item.id}" unless item.indexes.uniq.size == item.indexes.size
      end
      raise Error, 'Database-schema diagrams require one to six foreign keys' unless foreign_keys.size.between?(1, 6)
      foreign_keys.each do |item|
        source = tables.find { |table_item| table_item.id == item.from_table }
        target = tables.find { |table_item| table_item.id == item.to_table }
        raise Error, "Unknown foreign-key source table: #{item.from_table}" unless source
        raise Error, "Unknown foreign-key target table: #{item.to_table}" unless target
        source_column = source.columns.find { |column_item| column_item.id == item.from_column }
        target_column = target.columns.find { |column_item| column_item.id == item.to_column }
        raise Error, "Unknown foreign-key source column: #{item.from_table}.#{item.from_column}" unless source_column
        raise Error, "Unknown foreign-key target column: #{item.to_table}.#{item.to_column}" unless target_column
        raise Error, "Foreign-key source #{item.from_table}.#{item.from_column} requires an explicit FK constraint" unless source_column.constraints.include?(:fk)
        unless (target_column.constraints & %i[pk uq]).any?
          raise Error, "Foreign-key target #{item.to_table}.#{item.to_column} requires an explicit PK or UQ constraint"
        end
      end
      tables.each do |item|
        item.columns.each { |column_item| column_item.constraints.freeze; column_item.freeze }
        item.columns.freeze
        item.indexes.freeze
        item.overflow&.freeze
        item.freeze
      end
      tables.freeze
      foreign_keys.each(&:freeze)
      foreign_keys.freeze
    end
  end
end

SlimGraphR::Diagram.prepend(SlimGraphR::DatabaseSchemaDSL)
