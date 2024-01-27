module Mensa
  module SharedDsl
    extend ActiveSupport::Concern

    class_methods do
      def option(name)
        define_method name.to_sym do |value=nil, &block|
          if block_given?
            config[name.to_sym] = block
          else
            config[name.to_sym] = value
          end
        end
      end
    end

    included do

      def filter(&block)
        config[:filter] = block
      end

      def order(value)
        config[:order] = value
      end
    end
  end
end