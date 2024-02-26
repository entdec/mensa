# frozen_string_literal: true

# Presents a single table-view, also in use when just one table is in view
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
