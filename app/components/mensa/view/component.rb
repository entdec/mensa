# frozen_string_literal: true

module Mensa
  module View
    class Component < ::Mensa::ApplicationComponent
      include TablesHelper

      attr_reader :table

      def initialize(table:, view_context:)
        @table = table
        @table.view_context = view_context
      end

      def custom_classes
        custom_classes = []
        custom_classes << "mensa-table__condensed" if table.config[:view_condensed]

        custom_classes.join(" ")
      end
    end
  end
end
