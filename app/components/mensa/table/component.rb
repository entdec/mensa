# frozen_string_literal: true

module Mensa
  module Table
    class Component < ::Mensa::ApplicationComponent
      include TablesHelper

      attr_reader :table_name
      attr_reader :table
      attr_reader :card

      def initialize(table_name)
        @table_name = table_name
        @table = Mensa.for_name(table_name)
        @table.name = table_name
        @table.component = self
      end
      #
      # def table_url
      #   view_context.table_path(@table_name, params: params.reject do |p|
      #     %[action controller id].include?(p)
      #   end.permit!)
      # end
    end
  end
end