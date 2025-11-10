# frozen_string_literal: true

module Mensa
  class Filter
    include ConfigReaders
    attr_reader :column, :config, :table

    config_reader :operator
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

    def filter_scope(to_be_filtered_scope)
      if scope
        to_be_filtered_scope.instance_exec(normalize(value), &scope)
      else
        case operator
        when :matches
          to_be_filtered_scope.where("#{column.attribute_for_condition} LIKE ?", "%#{normalize(value)}%")
        when :equals
          to_be_filtered_scope.where(column.attribute_for_condition => normalize(value))
        else
          # Ignore unknown operators
          to_be_filtered_scope
        end
      end
    end

    private

    class << self
      def definition(&)
        @definition ||= Mensa::Config::FilterDsl.new(self.name, &).config
      end
    end

    def normalize(query)
      query.to_s.gsub(/\s(?![\&\!\|])/, '\\\\ ')
    end
  end
end
