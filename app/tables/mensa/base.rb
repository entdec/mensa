module Mensa
  class Base
    include Pagy::Method
    include ConfigReaders

    defined_by Mensa::Config::TableDsl
    include Scope

    attr_writer :original_view_context
    attr_accessor :component, :name, :table_view, :request
    attr_reader :params

    config_reader :model
    config_reader :link, call: false
    config_reader :supports_views?
    config_reader :supports_custom_views?
    config_reader :supports_filters?
    config_reader :view_condensed?
    config_reader :view_condensed_toggle?
    config_reader :view_columns_sorting?
    config_reader :show_header?
    config_reader :exportable?
    config_reader :export_with_password?

    def initialize(config = {})
      @params = config.to_h.deep_symbolize_keys
      @config = self.class.definition.merge(@params || {})
    end

    def column_order
      config[:column_order] || config[:columns]&.keys
    end

    # Returns all columns
    def columns
      @columns ||= column_order.map { |column_name| Mensa::Column.new(column_name, config: config.dig(:columns, column_name), table: self) }
    end

    # Returns a column by name
    # @param [String] name
    def column(name)
      columns.find { |c| c.name == name.to_sym }
    end

    # Returns the columns to be displayed
    def display_columns
      @display_columns ||= columns.select(&:visible?).reject(&:internal?)
    end

    # Returns the rows to be displayed
    def rows
      paged_scope.map { |row| Mensa::Row.new(self, row) }
    end

    def export_rows
      ordered_scope.map { |row| Mensa::Row.new(self, row) }
    end

    def system_views
      [Mensa::SystemView.new(:all, config: {name: I18n.t("mensa.views.all")}, table: self)] +
        (config[:views] || {}).keys.map { |view_name| Mensa::SystemView.new(view_name, config: config.dig(:views, view_name), table: self) }
    end

    # Returns true if the table has filters
    def filters?
      columns.any?(&:filter?)
    end

    # Returns the active filters
    def active_filters
      (config[:filters] || {}).map { |column_name, filter_config| Mensa::Filter.new(column: column(column_name), config: filter_config, table: self) }
    end

    def actions?
      config[:actions].present?
    end

    def actions
      return @actions if @actions

      @actions ||= config[:actions].keys.map { |action_name| Mensa::Action.new(action_name, config: config.dig(:actions, action_name), table: self) }
    end

    # Returns the current path with configuration
    def path(order: {}, turbo_frame_id: nil, table_view_id: nil)
      # FIXME: if someone doesn't use as: :mensa in the routes, it breaks
      original_view_context.mensa.table_path(name, order: order_hash(order), turbo_frame_id: turbo_frame_id, table_view_id: table_view_id)
    end

    def menu
      Satis::Menus::Builder.build([:table, :view_menu]) do |m|
        m.item :export, icon: "fal fa-file-export", link: nil
      end
    end

    def all_views
      views = system_views
      views += TableView.where(table_name: name).where(user: [nil, Current.user])
      views
    end

    def table_id
      return @table_id if @table_id

      @table_id = params[:turbo_frame_id] || "#{name.to_s.gsub("/", "__")}-#{SecureRandom.base36}"
    end

    def original_view_context
      @original_view_context || component.original_view_context
    end
  end
end
