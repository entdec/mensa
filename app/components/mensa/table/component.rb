# frozen_string_literal: true

module Mensa
  module Table
    class Component < ::Mensa::ApplicationComponent
      include TablesHelper

      attr_reader :table
      attr_reader :params

      def initialize(table_name, params: {}, **options)
        @params = params
        config = {params: params}
        view_lookup_table = Mensa.for_name(table_name, config)
        view = view_lookup_table.default_system_view

        table_config = (view&.config&.deep_transform_keys(&:to_sym) || {}).merge(config)
        @table = Mensa.for_name(table_name, table_config)
        @table.table_view = view
        @table.original_view_context = options[:original_view_context]
        @table.component = self
      end
    end
  end
end
