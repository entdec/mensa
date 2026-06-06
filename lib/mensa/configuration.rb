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
      order_indicator_asc: "fa-solid fa-arrow-up",
      order_indicator_desc: "fa-solid fa-arrow-down",
      control_bar_search: "fa-solid fa-magnifying-glass",
      control_bar_filter: "fa-solid fa-filter",
      control_bar_edit: "fa-solid fa-table-columns",
      control_bar_compress: "fa-solid fa-compress",
      control_bar_export: "fa-solid fa-file-export",
      search: "fa-solid fa-magnifying-glass",
      filters_add_filter: "fa-solid fa-plus"
    }
    # PRO
    # option :icons, default: {
    #   order_indicator_asc: "fa-regular fa-arrow-up-short-wide",
    #   order_indicator_desc: "fa-regular fa-arrow-down-wide-short",
    #   order_indicator: "fa-regular fa-arrow-down-arrow-up",
    #   control_bar_search: "fa-light fa-magnifying-glass",
    #   control_bar_filter: "fa-light fa-bars-filter",
    #   control_bar_edit: "fa-light fa-columns-3",
    #   control_bar_compress: "fa-light fa-compress",
    #   control_bar_export: "fa-light fa-file-export",
    #   search: "fa-light fa-magnifying-glass"
    # }

    option :callbacks, default: {
      # Called with the Mensa::Export when the export job starts processing.
      export_started: lambda do |export|
      end,
      # Called with the Mensa::Export once the CSV has been generated and
      # attached (export.asset). Use this to e.g. notify or email the user.
      export_complete: lambda do |export|
      end
    }

    option :row_actions_position, default: :back

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

    alias_method :setup, :configure

    def reset_config!
      @config = Configuration.new
    end
  end
end
