module Mensa
  module ConfigReaders
    extend ActiveSupport::Concern

    class_methods do
      def config_reader(name)
        define_method name do
          config[name.to_s.gsub("?", "").to_sym]
        end
      end
    end
  end
end