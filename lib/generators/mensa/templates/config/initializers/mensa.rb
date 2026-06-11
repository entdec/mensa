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
end
