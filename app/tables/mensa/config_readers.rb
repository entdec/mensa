module Mensa
  module ConfigReaders
    extend ActiveSupport::Concern

    included do
      attr_reader :config
    end

    class_methods do
      def defined_by(dsl_class)
        # Lazily-built DSL instance that accumulates configuration.
        define_singleton_method(:dsl_definition) do
          @dsl_definition ||= dsl_class.new(name)
        end

        define_singleton_method(:definition) do |&block|
          dsl_definition.instance_eval(&block) if block
          dsl_definition.config
        end

        # Forward unknown class-level calls to the DSL
        define_singleton_method(:method_missing) do |method_name, *args, &block|
          if dsl_definition.respond_to?(method_name)
            dsl_definition.public_send(method_name, *args, &block)
          else
            super(method_name, *args, &block)
          end
        end

        define_singleton_method(:respond_to_missing?) do |method_name, include_private = false|
          dsl_definition.respond_to?(method_name, include_private) || super(method_name, include_private)
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
