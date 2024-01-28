module Mensa::Config
  module DslLogic
    extend ActiveSupport::Concern

    attr_reader :config, :values

    delegate :default_config, to: :class

    def initialize(name, &)
      @config = {}
      @config[:name] = name if name
      @config = @config.merge(default_config.deep_dup)

      instance_eval(&) if block_given?
    end

    class_methods do
      attr_reader :default_config

      def option(name, default: nil, config_name: nil, dsl: nil, dsl_hash: nil, dsl_array: nil)
        if dsl
          dsl_option(name, dsl)
        elsif dsl_hash
          dsl_hash(name, dsl_hash, config_name: config_name)
        elsif dsl_array
          dsl_array(name, dsl_array, config_name: config_name)
        else
          simple_option(name, default: default)
        end
      end

      ###
      # Define a accessor method
      #
      # def name(value = nil, &)
      #   config[:name] = block || value
      # end
      #
      # by calling simple_option :name
      #
      def simple_option(option_name, default: nil)
        @default_config ||= {}
        @default_config[option_name.to_sym] = default

        define_method(option_name) do |value = nil, &block|
          config[option_name.to_sym] = block || value
        end
      end

      ###
      # Define a DSL method
      #
      # def render(name, &)
      #   config[:render] = Mensa::RenderDsl.new(name, &).config
      # end
      #
      # by calling define_dsl :render, Mensa::RenderDsl
      #
      def dsl_option(option_name, klass)
        define_method(option_name) do |name = nil, &block|
          config[option_name.to_sym] = block && klass.new(name, &block).config
        end
      end

      def dsl_hash(option_name, klass, config_name:)
        config_name = config_name || option_name.to_s.pluralize.to_sym

        @default_config ||= {}
        @default_config[option_name.to_sym] = {}

        define_method(option_name) do |name = nil, &block|
          config[config_name] ||= {}
          config[config_name][name] = klass.new(nil, &block).config
        end
      end

      def dsl_array(option_name, klass, config_name: option_name.to_s.pluralize.to_sym)
        config_name = config_name || option_name.to_s.pluralize.to_sym

        @default_config ||= {}
        @default_config[name.to_sym] = []

        define_method(option_name) do |name = nil, &block|
          config[config_name] ||= []
          config[config_name] << klass.new(name, &block).config
        end
      end
    end
  end
end
