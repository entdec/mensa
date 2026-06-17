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

    config_reader :sortable?
    config_reader :sanitize?
    config_reader :visible?
    config_reader :internal?
    config_reader :method # When a method needs to be called on the model, slow!
    config_reader :format

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
        Arel.sql("\"#{table.model.table_name}\".\"#{name}\"")
      end
    end

    # Returns true if the column supports filtering
    def filter?
      config[:filter] != false
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
  end
end
