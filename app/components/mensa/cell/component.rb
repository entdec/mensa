# frozen_string_literal: true

module Mensa
  module Cell
    class Component < ::Mensa::ApplicationComponent
      with_collection_parameter :cell

      include TablesHelper

      attr_reader :row
      attr_reader :cell

      def initialize(row:, cell:)
        @row = row
        @cell = cell
      end
    end
  end
end