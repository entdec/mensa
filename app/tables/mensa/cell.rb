# frozen_string_literal: true

module Mensa
  class Cell
    attr_reader :column, :row

    def initialize(column, row)
      @column = column
      @row = row
    end

    def value
      row.value(column)
    end

    def to_html
      # TODO: Sanitize
      value.to_s
    end
  end
end
