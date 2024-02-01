# frozen_string_literal: true

module Mensa
  module TableContainer
    class Component < ::Mensa::ApplicationComponent
      include TablesHelper

      attr_reader :table_name
      attr_reader :table
      attr_reader :card

      def initialize(table_name, card: nil)
        @table_name = table_name
        @table = Mensa.for_name(table_name)
        @table.name = table_name
        @table.view_context = view_context
        @card = card
      end

      def table_url
        view_context.table_path(@table_name, params: params.reject do |p|
          %[action controller id].include?(p)
        end.permit!)
      end
    end
  end
end