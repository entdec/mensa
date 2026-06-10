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
    config_reader :scope
    config_reader :link, call: false
    config_reader :supports_views?
    config_reader :supports_custom_views?
    config_reader :supports_filters?
    config_reader :view_columns_ordering?
    config_reader :show_header?
    config_reader :exportable?
    config_reader :export_with_password?

    def initialize(config = {})
      @params = config.to_h.deep_symbolize_keys
      @config = self.class.definition.merge(@params || {})

      ensure_internal_columns_for_joined_associations

      params[:hidden_columns]&.each do |column_name|
        c = columns.find { |c| c.name == column_name.to_sym }
        c.config[:visible] = false
      end
    end

    def column_order
      order = config[:column_order].presence || config[:columns]&.keys
      order = order&.map(&:to_sym)
      return order if order.nil?

      # Internal columns are never shown in the column customizer UI, so they
      # are absent from any URL-supplied column_order. Always append them so
      # that columns and selected_scope include their attributes.
      all_keys = (config[:columns]&.keys || []).map(&:to_sym)
      internal_keys = all_keys.select { |key| config.dig(:columns, key, :internal) }
      (order | internal_keys)
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

    # Returns the columns to be displayed, ordered by column_order.
    def display_columns
      @display_columns ||= begin
        order = column_order || []
        columns
          .select(&:visible?)
          .reject(&:internal?)
          .sort_by { |col| order.index(col.name) || Float::INFINITY }
      end
    end

    # Returns the rows to be displayed
    def rows
      paged_scope.map { |row| Mensa::Row.new(self, row) }
    end

    def export_rows
      ordered_scope.map { |row| Mensa::Row.new(self, row) }
    end

    def system_views
      views = config[:views]&.key?(:default) ? [] : [Mensa::SystemView.new(:default, config: {name: I18n.t("mensa.views.default")}, table: self)]
      views + (config[:views] || {}).keys.map { |view_name| Mensa::SystemView.new(view_name, config: config.dig(:views, view_name), table: self) }
    end

    # Returns true if the table has filters
    def filters?
      columns.any?(&:filter?)
    end

    # Returns the active filters, skipping any whose column no longer exists.
    def active_filters
      (config[:filters] || {}).filter_map do |column_name, filter_config|
        col = column(column_name)
        next unless col
        Mensa::Filter.new(column: col, config: filter_config, table: self)
      end
    end

    def actions?
      config[:actions].present?
    end

    def actions
      return @actions if @actions

      @actions ||= config[:actions].keys.map { |action_name| Mensa::Action.new(action_name, config: config.dig(:actions, action_name), table: self) }
    end

    def batch_actions?
      config[:batches].present?
    end

    def batch_actions
      return @batch_actions if @batch_actions

      @batch_actions ||= config[:batches].keys.map { |batch_name| Mensa::BatchAction.new(batch_name, config: config.dig(:batches, batch_name), table: self) }
    end

    # Returns the current path with configuration
    def path(order: {}, turbo_frame_id: nil, table_view_id: params[:table_view_id], column_order: params[:column_order], hidden_columns: params[:hidden_columns])
      # FIXME: if someone doesn't use as: :mensa in the routes, it breaks
      original_view_context.mensa.table_path(
        name,
        order: order_hash(order),
        turbo_frame_id: turbo_frame_id,
        table_view_id: table_view_id,
        column_order: column_order,
        hidden_columns: hidden_columns
      )
    end

    def all_views
      views = system_views
      views += TableView.where(table_name: name).where(user: [nil, current_user])
      views
    end

    # The user that owns custom views. Returns nil when the host application has
    # no current user, in which case views cannot be saved.
    def current_user
      return Current.user if defined?(Current) && Current.respond_to?(:user)

      nil
    end

    def table_id
      return @table_id if @table_id

      @table_id = params[:turbo_frame_id] || "#{name.to_s.gsub("/", "__")}-#{SecureRandom.base36}"
    end

    def original_view_context
      @original_view_context || component.original_view_context
    end

    private

    def ensure_internal_columns_for_joined_associations
      config[:columns] ||= {}

      auto_internal_column_names.each do |column_name|
        config[:columns][column_name] ||= {internal: true}
      end
    end

    def auto_internal_column_names
      joined_association_names.filter_map do |association_name|
        reflection = model.reflect_on_association(association_name)
        reflection&.foreign_key&.to_sym
      end.uniq
    end

    def joined_association_names
      relation = scope
      return [] unless relation.respond_to?(:joins_values) && relation.respond_to?(:left_outer_joins_values)

      (relation.joins_values + relation.left_outer_joins_values).flat_map do |join_value|
        association_names_from_join_value(join_value)
      end.compact.uniq
    end

    def association_names_from_join_value(join_value)
      case join_value
      when Symbol, String
        [join_value.to_sym]
      when Array
        join_value.flat_map { |value| association_names_from_join_value(value) }
      when Hash
        join_value.flat_map do |association_name, nested_join_values|
          [association_name.to_sym, *association_names_from_join_value(nested_join_values)]
        end
      else
        []
      end
    end
  end
end
