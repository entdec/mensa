# frozen_string_literal: true

module Mensa
  module Table
    class Component < ::Mensa::ApplicationComponent
      include TablesHelper

      attr_reader :table
      attr_reader :params

      def initialize(table_name, params: {}, **options)
        @params = params
        @table = Mensa.for_name(table_name, {params: params})
        @table.original_view_context = options[:original_view_context]
        @table.component = self
      end
    end
  end
end
