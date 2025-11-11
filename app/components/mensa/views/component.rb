# frozen_string_literal: true

module Mensa
  module Views
    class Component < ::Mensa::ApplicationComponent
      # renders_many :views
      attr_reader :table

      def initialize(table:)
        @table = table
      end
    end
  end
end
