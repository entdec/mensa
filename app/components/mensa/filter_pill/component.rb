# frozen_string_literal: true

module Mensa
  module FilterPill
    class Component < ::Mensa::ApplicationComponent
      with_collection_parameter :filter

      attr_reader :filter

      def initialize(filter:)
        @filter = filter
      end

      # A pill is a view filter only while it still filters like the view does,
      # once the user changes it, it's their own filter.
      def view_filter?
        view = filter.table.table_view
        return false unless view

        view_filters = view.config&.dig(:filters) || view.config&.dig("filters") || {}
        col = filter.column.name.to_s
        view_filter = view_filters[col] || view_filters[col.to_sym]
        return false unless view_filter

        view_filter = view_filter.to_h.with_indifferent_access
        return false if view_filter[:operator].present? && view_filter[:operator].to_sym != filter.operator

        comparable(view_filter[:value]) == comparable(filter.value)
      end

      private

      def comparable(value)
        Array(value).map(&:to_s).reject(&:blank?).sort
      end
    end
  end
end
