# frozen_string_literal: true

module Mensa
  module Table
    class Component < ::Mensa::ApplicationComponent
      include TablesHelper

      attr_reader :table
      attr_reader :params

      def initialize(table_name, config = {}, **options)
        @table = Mensa.for_name(table_name, config)
        @table.component = self
        @params = options[:params] || {}
      end
    end
  end
end
