module Mensa
  class Base
    include Pagy::Backend
    include ConfigReaders
    include Scope

    attr_accessor :view_context
    attr_reader :config, :params

    config_reader :model
    config_reader :link

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
    def path(order: {}, turbo_frame_id: nil)
      view_context.table_path(params[:id], order: order_hash(order), turbo_frame_id: turbo_frame_id)
    end

    def menu
      Satis::Menus::Builder.build([:table, :view_menu]) do |m|
        m.item :export, icon: "fal fa-file-export", link: nil
      end
    end

    private

    class << self
      def definition(&)
        @definition ||= Mensa::Config::TableDsl.new(self.name, &).config
      end
    end
  end
end
