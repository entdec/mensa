# frozen_string_literal: true

module Mensa
  class Filter
    include ConfigReaders
    attr_reader :column, :value, :config, :table

    config_reader :scope

    def initialize(value, column:, config:, table:)
      @value = value
      @column = column
      @config = config
      @table = table
    end

    def collection
      if config[:collection].is_a? Proc
        table.original_view_context.instance_exec(&config[:collection])
      else
        config[:collection]
      end
    end

    def to_s
      "#{column.human_name}: #{value}"
    end
  end
end
