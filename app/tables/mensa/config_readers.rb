module Mensa
  module ConfigReaders
    extend ActiveSupport::Concern

    class_methods do
      # Set call to false to avoid immediate execution of Procs
      def config_reader(name, call: true)
        define_method name do
          value = config[name.to_s.gsub("?", "").to_sym]
          call == true && value.is_a?(Proc) ? instance_exec(&value) : value
        end
      end
    end
  end
end
