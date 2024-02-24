# frozen_string_literal: true

module Mensa
  module View
    class Component < ::Mensa::ApplicationComponent
      include TablesHelper

      attr_reader :table

      def initialize(table)
        @table = table
      end
    end
  end
end
