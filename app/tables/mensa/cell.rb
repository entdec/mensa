# frozen_string_literal: true

module Mensa
  class Cell
    attr_reader :column, :row

    def initialize(row:, column:)
      @row = row
      @column = column
    end

    def value
      row.value(column)
    end

    def to_html
      value.to_s
    end
  end
end
