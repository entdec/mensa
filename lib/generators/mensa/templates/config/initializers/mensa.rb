Mensa.setup do |config|
  # Callbacks for exporting of tables
  config.callbacks = {
    export_started: lambda do |export|
    end,
    export_completed: lambda do |export|
    end
  }

  # Override icons in use
  config.icons = {
    add_filter_trigger: "fa-solid fa-circle-plus",
    add_filter_selected: "fal fa-check",
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
    filter_pill_list_search: "fa-solid fa-magnifying-glass",
    filter_pill_list_clear: "fa-solid fa-xmark",
    header_order_indicator_asc: "fa-solid fa-arrow-up",
    header_order_indicator_desc: "fa-solid fa-arrow-down",
    header_order_indicator_numeric_asc: "fa-solid fa-arrow-down-1-9",
    header_order_indicator_numeric_desc: "fa-solid fa-arrow-down-9-1",
    header_order_indicator_date_asc: "fa-solid fa-arrow-down-1-9",
    header_order_indicator_date_desc: "fa-solid fa-arrow-down-9-1",
    header_order_indicator_text_asc: "fa-solid fa-arrow-down-a-z",
    header_order_indicator_text_desc: "fa-solid fa-arrow-down-z-a",
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
end
