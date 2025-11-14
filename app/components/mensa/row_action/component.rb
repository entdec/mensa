# frozen_string_literal: true

module Mensa
  module RowAction
    class Component < ::Mensa::ApplicationComponent
      with_collection_parameter :action

      attr_reader :table
      attr_reader :row
      attr_reader :action

      def initialize(table:, row:, action:)
        @table = table
        @row = row
        @action = action
      end
    end
  end
end
