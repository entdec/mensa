# frozen_string_literal: true

module Mensa
  module Options
    module ClassMethods
      def option(name, default: nil, proc: false)
        attr_writer(name)
        schema[name] = {default: default, proc: proc}

        if schema[name][:proc]
          define_method(name) do |*params|
            value = instance_variable_get(:"@#{name}")
            instance_exec(*params, &value)
          end
        else
          define_method(name) do
            instance_variable_get(:"@#{name}")
          end
        end
      end

      def schema
        @schema ||= {}
      end
    end

    def set_defaults!
      self.class.schema.each do |name, options|
        instance_variable_set(:"@#{name}", options[:default])
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

    option :icons, default: {
      add_filter_trigger: "fa-solid fa-circle-plus",
      add_filter_selected: "fa-solid fa-check",
      column_customizer_toggle: "fa-solid fa-table-columns",
      column_customizer_handle: "fa-solid fa-grip-vertical",
      column_customizer_visibility_on: "fa-solid fa-eye",
      column_customizer_visibility_off: "fa-solid fa-eye-slash",
      control_bar_reset: "fa-solid fa-rotate-left",
      control_bar_save_dropdown: "fa-solid fa-chevron-down",
      control_bar_view_filters_show: "fa-solid fa-eye",
      control_bar_view_filters_hide: "fa-solid fa-eye-slash",
      control_bar_export: "fa-solid fa-file-export",
      empty_state_icon: "fa-solid fa-magnifying-glass",
      filter_pill_remove: "fa-solid fa-xmark",
      filter_pill_list_search: "fa-solid fa-sm fa-magnifying-glass",
      filter_pill_list_clear: "fa-solid fa-xmark",
      header_order_indicator_asc: "fa-solid fa-sm fa-arrow-up",
      header_order_indicator_desc: "fa-solid fa-sm fa-arrow-down",
      header_order_indicator_numeric_asc: "fa-solid fa-sm fa-arrow-down-1-9",
      header_order_indicator_numeric_desc: "fa-solid fa-sm fa-arrow-down-9-1",
      header_order_indicator_date_asc: "fa-solid fa-sm fa-arrow-down-1-9",
      header_order_indicator_date_desc: "fa-solid fa-sm fa-arrow-down-9-1",
      header_order_indicator_text_asc: "fa-solid fa-sm fa-arrow-down-a-z",
      header_order_indicator_text_desc: "fa-solid fa-sm fa-arrow-down-z-a",
      action_column_header: "fa-solid fa-ellipsis",
      views_trigger: "fa-solid fa-sort",
      views_option_selected: "fa-solid fa-check",
      views_option_menu: "fa-solid fa-ellipsis",
      views_option_system: "fa-solid fa-ban",
      views_rename: "fa-solid fa-pencil",
      views_duplicate: "fa-solid fa-copy",
      views_delete: "fa-solid fa-trash",
      exports_dialog_close: "fa-solid fa-xmark",
      exports_dialog_submit: "fa-solid fa-file-export",
      exports_list_delete: "fa-solid fa-trash",
      exports_list_download: "fa-solid fa-download",
      exports_list_processing: "fa-solid fa-spinner fa-spin",
      tables_standard_error: "fa-solid fa-circle-exclamation"
    }
    # PRO
    # option :icons, default: {
    #   add_filter_trigger: "fa-light fa-circle-plus",
    #   add_filter_selected: "fa-light fa-check",
    #   column_customizer_toggle: "fa-light fa-columns-3",
    #   column_customizer_handle: "fa-light fa-grip-vertical",
    #   column_customizer_visibility_on: "fa-light fa-eye",
    #   column_customizer_visibility_off: "fa-light fa-eye-slash",
    #   control_bar_reset: "fa-light fa-rotate-left",
    #   control_bar_save_dropdown: "fa-light fa-chevron-down",
    #   control_bar_view_filters_show: "fa-light fa-eye",
    #   control_bar_view_filters_hide: "fa-light fa-eye-slash",
    #   control_bar_export: "fa-light fa-file-export",
    #   empty_state_icon: "fa-light fa-magnifying-glass",
    #   filter_pill_remove: "fa-light fa-xmark",
    #   filter_pill_list_search: "fa-light fa-sm fa-magnifying-glass",
    #   filter_pill_list_clear: "fa-light fa-xmark",
    #   header_order_indicator_asc: "fa-regular fa-sm fa-arrow-up-short-wide",
    #   header_order_indicator_desc: "fa-regular fa-sm fa-arrow-down-wide-short",
    #   views_trigger: "fa-light fa-sort",
    #   views_option_selected: "fa-light fa-check",
    #   views_option_menu: "fa-light fa-ellipsis",
    #   views_option_system: "fa-light fa-ban",
    #   views_rename: "fa-light fa-pencil",
    #   views_duplicate: "fa-light fa-copy",
    #   views_delete: "fa-light fa-trash",
    #   exports_dialog_close: "fa-light fa-xmark",
    #   exports_dialog_submit: "fa-light fa-file-export",
    #   exports_list_delete: "fa-light fa-trash",
    #   exports_list_download: "fa-light fa-download",
    #   exports_list_processing: "fa-light fa-spinner fa-spin",
    #   tables_standard_error: "fa-light fa-circle-exclamation"
    # }

    option :callbacks, default: {
      # Called with the Mensa::Export when the export job starts processing.
      export_started: lambda do |export|
      end,
      # Called with the Mensa::Export once the CSV has been generated and
      # attached (export.asset). Use this to e.g. notify or email the user.
      #
      # UserMailer.with(
      #   user: User.find(export.user_id),
      #   export: export,
      # ).export_email.deliver_later
      export_complete: lambda do |export|
      end
    }

    # :front or :back (default)
    option :row_actions_position, default: :back
    # It's either :basic or :fuzzy, for fuzzy search you need to have `pg_trgm` extension installed
    option :search, default: :basic

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
