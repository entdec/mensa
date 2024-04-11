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
      # See https://github.com/textacular/textacular
      # This has problems - not all table fields are searched
      @filtered_scope = @filtered_scope.basic_search(params[:query]) if params[:query]

      if params[:filters]
        params[:filters].each do |column_name, value|
          next unless (column = column(column_name))

          @filtered_scope = if column.filter&.scope
                              @filtered_scope.instance_exec(Helper.normalize(value), &column.filter.scope)
                            else
                              @filtered_scope.where(column.attribute_for_condition => Helper.normalize(value))
                            end
        end
      end

      @filtered_scope
    end

    # Returns the filtered_columns, but ordered, we always reorder, scope shouldn't include ordering
    def ordered_scope
      return @ordered_scope if @ordered_scope

      @ordered_scope = filtered_scope
      @ordered_scope = @ordered_scope.reorder(order_hash)

      @ordered_scope
    end

    # Return the ordered_scope, but with only the columns selected
    def selected_scope
      return @selected_scope if @selected_scope

      @selected_scope = ordered_scope
      @selected_scope = @selected_scope.select([:id] + columns.map(&:attribute).compact)

      Rails.logger.debug("*" * 80)
      Rails.logger.debug("Selected scope")
      Rails.logger.debug(@selected_scope.to_sql)
      Rails.logger.debug("*" * 80)


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

      @pagy_details, @records = selected_scope.is_a?(Array) ? pagy_array(ordered_scope) : pagy(selected_scope)
    end

    # Though this works, perhaps moving this in column(s) is nicer
    def order_hash(new_params = {})
      (params[:order] || config[:order]).merge(new_params.symbolize_keys)
                                        .reject { |name, direction| direction.blank? }
                                        .transform_values { |value| value.to_sym }
    end

    module Helper
      class << self
        def normalize(query)
          query.to_s.gsub(/\s(?![\&\!\|])/, '\\\\ ')
        end
      end
    end
  end
end
