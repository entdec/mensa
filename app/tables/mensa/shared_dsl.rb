module Mensa
  module SharedDsl
    extend ActiveSupport::Concern

    included do

      def filter(&block)
        @config[:filter] = block
      end

      def order(value)
        @config[:order] = value
      end
    end
  end
end