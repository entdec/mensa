# frozen_string_literal: true

module Mensa
  module TableRow
    class Component < ::Mensa::ApplicationComponent
      with_collection_parameter :row

      include TablesHelper

      attr_reader :table
      attr_reader :row

      def initialize(table:, row:)
        @table = table
        @row = row
      end
    end
  end
end