# frozen_string_literal: true

module Mensa
  module Scope
    extend ActiveSupport::Concern

    included do
    end

    # Returns the records we want to display, using the Active Record Query Interface
    # By default it returns all records
    def scope
      model.all
    end

    # Returns the scope, but filtered
    def filtered_scope
      return @filtered_scope if @filtered_scope

      @filtered_scope = scope
      @filtered_scope = @filtered_scope.web_search(params[:query]) if params[:query]
      @filtered_scope
    end

    # Returns the filtered_columns, but ordered, we always reorder, scope shouldn't include ordering
    def ordered_scope
      return @ordered_scope if @ordered_scope

      @ordered_scope = filtered_scope
      @ordered_scope = @ordered_scope.reorder(order_hash) if params[:order]

      @ordered_scope
    end

    # Return the ordered_scope, but with only the columns selected
    def selected_scope
      return @selected_scope if @selected_scope

      @selected_scope = ordered_scope
      @selected_scope = @selected_scope.select([:id] + columns.map(&:attribute))

      @selected_scope
    end

    def paged_scope
      pagyd
      @records
    end

    def pagy_details
      pagyd
      @pagy_details
    end

    private

    def pagyd
      return if @pagy_details && @records

      @pagy_details, @records = selected_scope.is_a?(Array) ? pagy_array(ordered_scope) : pagy(selected_scope)
    end

    # Though this works, perhaps moving this in column(s) is nicer
    def order_hash(new_params = {})
      order_params = params[:order] || {}
      order_params.reject { |name, direction| direction.blank? }.to_h
                  .merge(new_params.symbolize_keys)
                  .reject { |name, direction| direction.blank? }
    end
  end
end
