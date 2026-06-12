# frozen_string_literal: true

module Mensa
  module EmptyState
    class Component < ::Mensa::ApplicationComponent
      attr_reader :table

      def initialize(table:)
        @table = table
      end

      # "orders", "users", etc. — used inside the translated heading.
      def model_name_plural
        table.model.model_name.human(count: 2).downcase
      end
    end
  end
end
