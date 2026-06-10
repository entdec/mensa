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

    def sort_direction
      value = table.config.dig(:order, name)
      value.present? ? value.to_sym : nil
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
        name.to_s
      end
    end

    def active_record_column
      @active_record_column ||= table.model&.columns&.find { it.name == name.to_s }
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
        config[:attribute]
      elsif table.model.column_names.include? name.to_s
        name.to_s
      end
    end

    # Returns true if the column supports filtering
    def filter?
      config.key?(:filter)
    end

    def filter
      return unless filter?

      @filter ||= Mensa::Filter.new(column: self, config: table.config.dig(:columns, name, :filter) || {}, table: table)
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
