# frozen_string_literal: true

module Mensa
  module Table
    class Component < ::Mensa::ApplicationComponent
      include TablesHelper

      attr_reader :table

      def initialize(table:, view_context:)
        @table = table
        @table.view_context = view_context
      end
    end
  end
end