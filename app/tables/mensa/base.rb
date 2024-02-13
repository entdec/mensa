module Mensa
  class Base
    include Pagy::Backend
    include ConfigReaders
    include Scope

    attr_accessor :view_context, :name, :table_view
    attr_reader :config, :params

    config_reader :model
    config_reader :link
    config_reader :supports_views?
    config_reader :show_header?

    def initialize(config = {})
      @params = config.deep_symbolize_keys
      @config = self.class.definition.merge(@params || {})
    end

    def column_order
      config[:column_order] || config[:columns]&.keys
    end

    # Returns all columns
    def columns
      return @columns if @columns

      @columns ||= column_order.map { |column_name| Mensa::Column.new(column_name, config: config.dig(:columns, column_name), table: self) }
    end

    # Returns a column by name
    # @param [String] name
    def column(name)
      columns.find { |c| c.name == name.to_sym }
    end

    def rows
      paged_scope.map { |row| Mensa::Row.new(self, view_context, row) }
    end

    # Returns the current path with configuration
    def path(order: {}, turbo_frame_id: nil, table_view_id: nil)
      view_context.table_path(params[:id], order: order_hash(order), turbo_frame_id: turbo_frame_id, table_view_id: table_view_id)
    end

    def menu
      Satis::Menus::Builder.build([:table, :view_menu]) do |m|
        m.item :export, icon: "fal fa-file-export", link: nil
      end
    end

    def all_views
      [Mensa::TableView.new(name: I18n.t('.mensa.views.all'))] + TableView.where(table_name: name).where(user: [nil, Current.user])
    end

    def active_filters
      (config[:filters] || {}).map { |column_name, value| Mensa::Filter.new(value, column: column(column_name), config: config.dig(:filters, column_name), table: self) }
    end

    def table_id
      return @table_id if @table_id

      @table_id = params[:turbo_frame_id] || "#{name}-#{SecureRandom.base36}"
    end

    private

    class << self
      def definition(&)
        @definition ||= Mensa::Config::TableDsl.new(self.name, &).config
      end
    end
  end
end
