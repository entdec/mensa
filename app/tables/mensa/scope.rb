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

    def filtered_scope
      scope
    end

    def ordered_scope
      return @ordered_scope if @ordered_scope

      @ordered_scope = filtered_scope

      @ordered_scope = @ordered_scope.reorder(order_hash) if params[:order]

      @ordered_scope
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

      @pagy_details, @records = ordered_scope.is_a?(Array) ? pagy_array(ordered_scope) : pagy(ordered_scope)
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
