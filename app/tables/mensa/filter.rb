# frozen_string_literal: true

module Mensa
  class Filter
    include ConfigReaders

    defined_by Mensa::Config::FilterDsl

    attr_reader :column, :table

    config_reader :operator, cast: :to_sym
    config_reader :value
    config_reader :scope

    def initialize(column:, config:, table:)
      @column = column
      @config = self.class.definition.merge(config || {})
      @table = table
    end

    def collection
      return unless config&.key?(:collection)

      if config[:collection].is_a? Proc
        table.original_view_context.instance_exec(&config[:collection])
      else
        config[:collection]
      end
    end

    def to_s
      "#{column.human_name}: #{value}"
    end

    def filter_scope(record_scope)
      if scope
        record_scope.instance_exec(normalize(value), &scope)
      else
        case operator
        when :matches
          record_scope.where("#{column.attribute_for_condition} LIKE ?", "%#{normalize(value)}%")
        when :equals
          record_scope.where(column.attribute_for_condition => normalize(value))
        else
          # Ignore unknown operators
          record_scope
        end
      end
    end

    private

    def normalize(query)
      query.to_s.gsub(/\s(?![&!|])/, '\\\\ ')
    end
  end
end
