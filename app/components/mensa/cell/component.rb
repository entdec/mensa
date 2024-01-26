# frozen_string_literal: true

module Mensa
  class Cell
    class Component < ::Mensa::ApplicationComponent
      with_collection_parameter :column

      include TablesHelper

      attr_reader :row, :column, :cell

      def initialize(row:, column:)
        @row = row
        @column = column
        @cell = ::Mensa::Cell.new(column, row)
      end
    end
  end
end
