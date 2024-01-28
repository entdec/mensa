# frozen_string_literal: true

module Mensa
  class Cell
    class Component < ::Mensa::ApplicationComponent
      with_collection_parameter :column

      attr_reader :cell

      def initialize(row:, column:)
        @cell = ::Mensa::Cell.new(row: row, column: column)
      end
    end
  end
end
