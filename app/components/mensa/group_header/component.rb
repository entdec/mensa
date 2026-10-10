# frozen_string_literal: true

module Mensa
  module GroupHeader
    # The header row above each group of rows in a grouped table
    class Component < ::Mensa::ApplicationComponent
      attr_reader :table, :group

      def initialize(table:, group:)
        @table = table
        @group = group
      end

      # The cells before the display columns (checkbox, front actions)
      def leading_cells
        (table.batch_actions? ? 1 : 0) + ((table.actions? && Mensa.config.row_actions_position == :front) ? 1 : 0)
      end

      def trailing_cells
        (table.actions? && Mensa.config.row_actions_position == :back) ? 1 : 0
      end

      # The title spans the columns up to the first one with an aggregate, so
      # the aggregates line up with their columns.
      def title_columns
        columns = table.display_columns
        index = columns.index { |column| aggregate?(column) } || columns.size
        columns.first([index, 1].max)
      end

      def aggregate_columns
        table.display_columns.drop(title_columns.size)
      end

      def aggregate?(column)
        group.aggregates.key?(column.name)
      end
    end
  end
end
