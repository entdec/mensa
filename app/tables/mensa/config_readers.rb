module Mensa
  module ConfigReaders
    extend ActiveSupport::Concern

    included do
      attr_reader :config
    end

    class_methods do
      def defined_by(dsl_class)
        define_singleton_method(:definition) do |&block|
          @definition ||= dsl_class.new(name, &block).config
        end
      end

      # Set call to false to avoid immediate execution of Procs
      def config_reader(name, call: true, cast: nil)
        define_method name do
          value = config[name.to_s.delete("?").to_sym]
          value = (call == true && value.is_a?(Proc)) ? instance_exec(&value) : value
          value = value.send(cast) if cast
          value
        end
      end
    end
  end
end
