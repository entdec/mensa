# frozen_string_literal: true

module Mensa
  # scope -> filtered_scope -> ordered_scope -> selected_scope ->
  module Scope
    extend ActiveSupport::Concern

    included do
    end

    # Returns the scope, but filtered
    def filtered_scope
      return @filtered_scope if @filtered_scope

      @filtered_scope = scope
      # See https://github.com/textacular/textacular
      # This has problems - not all table fields are searched
      if params[:query].present?
        @filtered_scope = if Mensa.config.search == :fuzzy
          @filtered_scope.fuzzy_search(params[:query])
        else
          @filtered_scope.basic_search(params[:query])
        end
      end

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
      @ordered_scope = @ordered_scope.reorder(effective_order)

      @ordered_scope
    end

    # Return the ordered_scope, but with only the columns selected
    def selected_scope
      return @selected_scope if @selected_scope

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

    private

    def pagy_object
      return if @pagy_details && @records

      @pagy_details, @records = selected_scope.is_a?(Array) ? pagy(:offset, ordered_scope, anchor_string: 'data-turbo-frame="_self"') : pagy(:offset, selected_scope, anchor_string: 'data-turbo-frame="_self"')
    end

    # Effective ordering for SQL: when the request includes any order[] params
    # (even with blank values), use only those — blank means "explicitly no sort".
    # Falls back to the view/config default only when no order params were sent.
    def effective_order
      result = params.key?(:order) ? (params[:order] || {}) : (config[:order] || {})
      result = result.symbolize_keys.compact_blank.transform_values(&:to_sym)
      result.transform_keys { column(_1).attribute_for_condition }
    end

    # Builds an order hash for URL generation. Merges current order with overrides;
    # nil values become "" so they appear in the URL as order[col]= (which tells
    # the server the user explicitly cleared that column's sort direction).
    def order_hash(new_params = {})
      base = params[:order]&.symbolize_keys || config[:order]&.symbolize_keys || {}
      merged = base.merge(new_params.symbolize_keys)
      merged.transform_values { |v| v.nil? ? "" : v.to_sym }
    end
  end
end
