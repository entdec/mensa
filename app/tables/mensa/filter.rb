# frozen_string_literal: true

module Mensa
  class Filter
    include ConfigReaders

    defined_by Mensa::Config::FilterDsl

    attr_reader :column, :table

    config_reader :operator, cast: :to_sym
    config_reader :value
    config_reader :scope
    config_reader :multiple

    def initialize(column:, config:, table:)
      @column = column
      @config = self.class.definition.merge(config || {})
      @table = table
    end

    def multiple?
      !!multiple
    end

    def collection
      return unless config&.key?(:collection)

      if config[:collection].is_a? Proc
        table.original_view_context.instance_exec(&config[:collection])
      else
        config[:collection]
      end
    end

    # This defines how the filter should be displayed in the value popover
    # :select => as a select input
    # :checkbox => as a checkbox input
    # :string => as a text input
    def as
      config[:as]
    end

    def to_s
      "#{column.human_name} #{operator_label} #{value}"
    end

    def filter_scope(record_scope)
      if scope
        record_scope.instance_exec(normalize(value), &scope)
      else
        case operator
        when :matches
          record_scope.where("#{column.attribute_for_condition} LIKE ?", "%#{normalize(value)}%")
        when :equals
          val = value.is_a?(Array) ? value : normalize(value)
          record_scope.where(column.attribute_for_condition => val)
        when :not_equals
          val = value.is_a?(Array) ? value : normalize(value)
          record_scope.where.not(column.attribute_for_condition => val)
        else
          # Ignore unknown operators
          record_scope
        end
      end
    end

    def operator_label
      case operator
      when :equals then "is"
      when :not_equals then "is not"
      when :matches then "contains"
      else "is"
      end
    end

    private

    def normalize(query)
      query.to_s.gsub(/\s(?![&!|])/, '\\\\ ')
    end
  end
end
