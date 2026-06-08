# frozen_string_literal: true

module Mensa
  module FilterPill
    class Component < ::Mensa::ApplicationComponent
      with_collection_parameter :filter

      attr_reader :filter

      def initialize(filter:)
        @filter = filter
      end

      def view_filter?
        view = filter.table.table_view
        return false unless view

        view_filters = view.config&.dig(:filters) || view.config&.dig("filters") || {}
        col = filter.column.name.to_s
        view_filters.key?(col) || view_filters.key?(col.to_sym)
      end
    end
  end
end
