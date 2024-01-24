# frozen_string_literal: true

module Mensa
  module Header
    class Component < ::Mensa::ApplicationComponent
      with_collection_parameter :column

      include TablesHelper

      attr_reader :table
      attr_reader :column

      def initialize(table:, column:)
        @table = table
        @column = column
      end
    end
  end
end