module Mensa
  module TableNavigation
    private

    def traversed_mensa_table(table_name)
      table = Mensa.for_name(table_name, traversed_mensa_table_config)
      table.request = request
      table.original_view_context = helpers
      table
    end

    def traversed_mensa_table_config
      filters_provided = params.key?(:filters)
      config = params.permit(:query, :table_view_id, order: {}, column_order: [], hidden_columns: [], params: {}, filters: {}).to_h
      config[:filters] = {} if filters_provided && !config.key?(:filters)
      config
    end

    def mensa_navigation_params
      traversed_mensa_table_config
    end
  end
end
