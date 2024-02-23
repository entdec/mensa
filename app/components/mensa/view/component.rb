# frozen_string_literal: true

module Mensa
  module View
    class Component < ::Mensa::ApplicationComponent
      include TablesHelper

      attr_reader :table

      def initialize(table, view_context:nil)
        @table = table
        # @table.view_context = view_context
        # @table_name = table_name
        # @table = Mensa.for_name(table_name)
        # @table.name = table_name
        # @table.view_context = view_context
      end
    end
  end
end
