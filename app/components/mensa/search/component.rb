# frozen_string_literal: true

module Mensa
  module Search
    class Component < ::Mensa::ApplicationComponent
      attr_reader :table

      def initialize(table:)
        @table = table
      end
    end
  end
end