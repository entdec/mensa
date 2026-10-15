# frozen_string_literal: true

module Mensa
  class Column
    include ConfigReaders

    defined_by Mensa::Config::ColumnDsl

    attr_reader :name, :table

    def initialize(name, config:, table:)
      @name = name
      @config = self.class.definition.merge(config || {})
      @table = table
    end

    config_reader :sanitize?
    config_reader :visible?
    config_reader :internal?
    config_reader :method # When a method needs to be called on the model, slow!
    config_reader :format

    AGGREGATE_FUNCTIONS = %i[count sum min max].freeze

    # The record method that gives the value: `method :to_s` names one,
    # `method true` uses the column's name
    def value_method
      config[:method] == true ? name : config[:method].presence
    end

    def sort_direction
      value = table.config.dig(:order, name)
      value.presence&.to_sym
    end

    def next_sort_direction
      if sort_direction == :asc
        :desc
      elsif sort_direction == :desc
        nil
      else
        :asc
      end
    end

    def attribute
      return @attribute if @attribute

      @attribute = if config[:attribute].present?
        "#{config[:attribute]} AS #{name}"
      elsif table.model.column_names.include? name.to_s
        "#{table.model.table_name}.#{name}"
      end
    end

    def raw_attribute
      return @raw_attribute if @raw_attribute

      @raw_attribute = if config[:attribute].present?
        config[:attribute]
      elsif table.model.column_names.include? name.to_s
        "#{table.model.table_name}.#{name}"
      end
    end

    def active_record_column
      @active_record_column ||= table.model&.columns&.find { |column| column.name == name.to_s }
    end

    def active_record_column_type
      active_record_column&.type
    end

    def type
      config[:type] || active_record_column_type
    end

    def attribute_for_condition
      return @attribute_for_condition if @attribute_for_condition

      @attribute_for_condition = if config[:attribute].present?
        Arel.sql(raw_attribute)
      elsif table.model.column_names.include? name.to_s
        Arel.sql("#{table.model.connection.quote_table_name(table.model.table_name)}.#{table.model.connection.quote_column_name(name)}")
      end
    end

    # Grouping and aggregating happen in SQL, so the column needs an attribute
    def groupable?
      config[:groupable] == true && attribute_for_condition.present?
    end

    # The aggregate functions the user can choose for this column
    def aggregates
      return [] if attribute_for_condition.blank?

      Array(config[:aggregates]).map(&:to_sym) & AGGREGATE_FUNCTIONS
    end

    def aggregatable?
      aggregates.any?
    end

    # Whether the column has SQL (an attribute or a database column). Columns
    # without, e.g. only a render block or a method, can't be sorted or
    # filtered in SQL.
    def sql?
      attribute_for_condition.present?
    end

    # Columns with SQL are sortable unless `sortable false`, others only with
    # an explicit `sortable true`
    def sortable?
      config[:sortable].nil? ? sql? : !!config[:sortable]
    end

    # Returns true if the column supports filtering: columns with SQL unless
    # `filter false`, others only with a filter that has its own scope
    def filter?
      return false if config[:filter] == false

      sql? || (config[:filter].is_a?(Hash) && config[:filter][:scope].present?)
    end

    def filter
      return unless filter?

      @filter ||= Mensa::Filter.new(column: self, config: table.config.dig(:columns, name, :filter) || {}, table: table)
    end

    def format
      @format ||= Mensa::Format.new(config: config.dig(:format).presence || {}, column: self)
    end

    def human_name
      if table.model < ActiveRecord::Base
        table.model.human_attribute_name name
      else
        name.to_s.humanize
      end
    end

    # Determines the sort indicator icon key based on column type
    def sort_indicator_icon_key
      numeric_types = [:integer, :decimal, :float, :bigint]
      date_types = [:date, :datetime, :time, :timestamp]
      text_types = [:string, :text]

      column_type = type
      direction = sort_direction.to_s.presence || ""
      direction_suffix = direction.present? ? "_#{direction}" : ""

      case column_type
      when *numeric_types
        "header_order_indicator_numeric#{direction_suffix}"
      when *date_types
        "header_order_indicator_date#{direction_suffix}"
      when *text_types
        "header_order_indicator_text#{direction_suffix}"
      else
        "header_order_indicator#{direction_suffix}"
      end
    end
  end
end
