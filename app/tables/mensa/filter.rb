# frozen_string_literal: true

module Mensa
  class Filter
    attr_reader :column, :value, :config, :table

    def initialize(value, column:, config:, table:)
      @value = value
      @column = column
      @config = config
      @table = table
    end

    def to_s
      "#{column.human_name}: #{value}"
    end
  end
end
