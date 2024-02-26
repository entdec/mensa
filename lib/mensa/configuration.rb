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

    # TODO: add all icons below
    option :icons, default: {
      order_indicator_asc: "fa-solid fa-sort-up",
      order_indicator_desc: "fa-solid fa-sort-down",
      order_indicator: "fa-solid fa-sort"
    }

    option :callbacks, default: {
      # Callback is called when the export is started,
      # the return value is passed as context to the export_complete callback
      export_started: lambda do |user_id, table_name|
      end,
      export_complete: lambda do |user_id, table_name, context, attachment|
      end
    }

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
