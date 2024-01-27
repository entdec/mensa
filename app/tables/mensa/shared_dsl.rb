module Mensa
  module SharedDsl
    extend ActiveSupport::Concern

    class_methods do
      def option(name)
        define_method name do |value=nil, &block|
          if block
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

      option :order
    end
  end
end