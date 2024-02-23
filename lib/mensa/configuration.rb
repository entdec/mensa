# frozen_string_literal: true

module Mensa
  module Options
    module ClassMethods
      def option(name, default: nil)
        attr_accessor(name)
        schema[name] = default
      end

      def schema
        @schema ||= {}
      end
    end

    def set_defaults!
      self.class.schema.each do |name, default|
        instance_variable_set("@#{name}", default)
      end
    end

    def self.included(cls)
      cls.extend(ClassMethods)
    end
  end

  class Configuration
    include Options

    option :logger, default: Rails.logger
    option :base_controller, default: "::ApplicationController"
    option :order_indicator_icons, default: { asc: "fa-arrow-up-short-wide", desc: "fa-arrow-down-wide-short", nil => "fa-arrow-down-arrow-up" }

    def initialize
      set_defaults!
    end
  end

  module Configurable
    attr_writer :config

    def config
      @config ||= Configuration.new
    end

    def configure
      yield(config)
    end

    alias setup configure

    def reset_config!
      @config = Configuration.new
    end
  end

end
