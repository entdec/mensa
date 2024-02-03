# frozen_string_literal: true

module Mensa
  module ControlBar
    class Component < ::Mensa::ApplicationComponent
      attr_reader :table

      def initialize(table:)
        @table = table
      end

      def sort_button?
        table.config[:view_colums_sorting]
      end

      def condense_button?
        table.config[:view_condensed_toggle]
      end
    end
  end
end
