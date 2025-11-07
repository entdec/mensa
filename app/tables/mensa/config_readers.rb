module Mensa
  module ConfigReaders
    extend ActiveSupport::Concern

    class_methods do
      # Having proc here should not necessary, but not having it gave me issues with row links
      def config_reader(name, proc: false)
        define_method name do
          value = config[name.to_s.gsub("?", "").to_sym]
          proc == true && value.is_a?(Proc) ? instance_exec(&value) : value
        end
      end
    end
  end
end
