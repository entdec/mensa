# frozen_string_literal: true

module Mensa
  module ControlBar
    class Component < ::Mensa::ApplicationComponent
      attr_reader :table

      def initialize(table:)
        @table = table
      end

      def view_columns_sorting?
        table.view_columns_sorting?
      end

      def view_condensed_toggle?
        table.view_condensed_toggle?
      end
    end
  end
end
