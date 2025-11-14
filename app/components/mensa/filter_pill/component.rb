# frozen_string_literal: true

module Mensa
  module FilterPill
    class Component < ::Mensa::ApplicationComponent
      with_collection_parameter :filter

      attr_reader :filter

      def initialize(filter:)
        @filter = filter
      end
    end
  end
end
