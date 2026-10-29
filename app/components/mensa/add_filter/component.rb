# frozen_string_literal: true

module Mensa
  module AddFilter
    class Component < Mensa::ApplicationComponent
      attr_reader :table

      def initialize(table:)
        @table = table
      end

      def operator_labels
        Mensa::Filter.OPERATORS.to_h do |name, label, _requires_value|
          [name, label]
        end
      end
    end
  end
end
