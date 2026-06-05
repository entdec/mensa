# frozen_string_literal: true

module Mensa
  module ControlBar
    class Component < ::Mensa::ApplicationComponent
      attr_reader :table

      def initialize(table:)
        @table = table
      end

      def view_columns_ordering?
        table.view_columns_ordering?
      end
    end
  end
end
