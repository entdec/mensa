# frozen_string_literal: true

module Mensa
  # scope -> filtered_scope -> ordered_scope -> selected_scope ->
  module Scope
    extend ActiveSupport::Concern
    include Search

    included do
    end

    # Returns the scope, but filtered
    def filtered_scope
      return @filtered_scope if @filtered_scope

      @filtered_scope = scope
      @filtered_scope = search(@filtered_scope, current_query) if current_query.present?

      # Use inject
      active_filters.each do |filter|
        @filtered_scope = filter.filter_scope(@filtered_scope)
      end

      @filtered_scope
    end

    # Returns the filtered_columns, but ordered, we always reorder, scope shouldn't include ordering
    def ordered_scope
      return @ordered_scope if @ordered_scope

      @ordered_scope = filtered_scope
      @ordered_scope = if effective_order.present?
        @ordered_scope.reorder(effective_order)
      elsif search_order_clause.present?
        @ordered_scope.reorder(Arel.sql(search_order_clause))
      else
        @ordered_scope.reorder(nil)
      end

      @ordered_scope
    end

    # Return the ordered_scope, but with only the columns selected
    def selected_scope
      return @selected_scope if @selected_scope

      ensure_internal_columns_for_joined_associations

      @selected_scope = ordered_scope
      @selected_scope = @selected_scope.select([:id] + columns.filter_map(&:attribute))

      @selected_scope
    end

    def paged_scope
      pagy_object
      @records
    end

    def pagy_details
      pagy_object
      @pagy_details
    end

    # Returns the next record in the fully filtered/ordered result set.
    # Pagination is intentionally ignored.
    def next_record(record)
      adjacent_record(record, step: 1)
    end

    # Returns the previous record in the fully filtered/ordered result set.
    # Pagination is intentionally ignored.
    def previous_record(record)
      adjacent_record(record, step: -1)
    end

    private

    def adjacent_record(record, step:)
      records = ordered_scope.to_a
      index = records.find_index { |candidate| same_record?(candidate, record) }
      return if index.nil?

      adjacent_index = index + step
      return if adjacent_index.negative? || adjacent_index >= records.length

      records[adjacent_index]
    end

    def same_record?(left, right)
      return false if left.nil? || right.nil?

      if left.respond_to?(:id) && right.respond_to?(:id)
        left.id == right.id
      else
        left == right
      end
    end

    def pagy_object
      return if @pagy_details && @records

      @pagy_details, @records = selected_scope.is_a?(Array) ? pagy(:offset, ordered_scope, anchor_string: 'data-turbo-frame="_self"') : pagy(:offset, selected_scope, anchor_string: 'data-turbo-frame="_self"')
    end

    # Effective ordering for SQL: when the request includes any order[] params
    # (even with blank values), use only those — blank means "explicitly no sort".
    # Falls back to the view/config default only when no order params were sent.
    def effective_order
      result = current_order_provided? ? (current_order || {}) : (config[:order] || {})
      result = result.symbolize_keys.compact_blank.transform_values(&:to_sym)
      result.filter_map { |k, v|
        attribute = column(k)&.attribute_for_condition || k
        "#{attribute} #{v} NULLS LAST"
      }.join(", ")
    end

    # Builds an order hash for URL generation. Merges current order with overrides;
    # nil values become "" so they appear in the URL as order[col]= (which tells
    # the server the user explicitly cleared that column's sort direction).
    def order_hash(new_params = {})
      base = current_order&.symbolize_keys || config[:order]&.symbolize_keys || {}
      merged = base.merge(new_params.symbolize_keys)
      merged.transform_values { |v| v.nil? ? "" : v.to_sym }
    end
  end
end
