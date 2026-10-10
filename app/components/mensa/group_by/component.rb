# frozen_string_literal: true

module Mensa
  module GroupBy
    # Lets the user choose the column to group by and the aggregates shown in
    # the group headers
    class Component < ::Mensa::ApplicationComponent
      attr_reader :table

      def initialize(table:)
        @table = table
      end

      def render?
        groupable_columns.any?
      end

      def groupable_columns
        @groupable_columns ||= table.columns.reject(&:internal?).select(&:groupable?)
      end

      def aggregatable_columns
        @aggregatable_columns ||= table.columns.reject(&:internal?).select(&:aggregatable?)
      end
    end
  end
end
