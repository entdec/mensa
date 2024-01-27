module Mensa
  class Base
    include Pagy::Backend
    include ConfigReaders

    attr_accessor :view_context
    attr_reader :params
    delegate :config, to: :class

    def initialize(params)
      @params = params
      # FIXME: With this order will work as default order, once the table is resorted, the default should go
      if params[:order].blank?
        params[:order] = order
      end
    end

    # Returns all columns
    def columns
      return @columns if @columns

      if column_order.present?
        column_order.map { |c| Mensa::Column.new(self, config[:columns].find {|cfg| cfg[:name] == c}) }
      else
        @columns = config[:columns].map { |config| Mensa::Column.new(self, config) }
      end
    end

    # Returns a column by name
    # @param [String] name
    def column(name)
      columns.find { |c| c.name == name.to_sym }
    end

    config_reader :model
    config_reader :link
    config_reader :order
    config_reader :column_order

    # Returns the records we want to display, using the Active Record Query Interface
    # By default it returns all records
    def scope
      model.all
    end

    def filtered_scope
      scope
    end

    def ordered_scope
      return @ordered_scope if @ordered_scope

      @ordered_scope = filtered_scope

      @ordered_scope = @ordered_scope.reorder(order_hash) if params[:order]

      @ordered_scope
    end

    def paged_scope
      pagyd
      @records
    end

    def pagy_details
      pagyd
      @pagy_details
    end

    def rows
      paged_scope.map { |row| Mensa::Row.new(self, view_context, row) }
    end

    # Returns the current path with configuration
    def path(order: {})
      view_context.table_path(params[:id], order: order_hash(order))
    end

    class << self

      def for_name(name, params = {})
        class_for_name(name).new(params)
      end

      def class_for_name(name)
        class_name = "#{name}_table".camelcase
        unless class_name.safe_constantize
          module_class_name = name.to_s.split('_', 2).map(&:camelcase).join('::') + 'Table'
          class_name = module_class_name if module_class_name.safe_constantize
        end
        Kernel.const_get("::#{class_name}")
      rescue NameError
        raise NotImplementedError, "No '#{name}' table defined."
      end

      def config(&)
        @config = Mensa::TableDsl.new(self.name, &).config if block_given?
        @config
      end
    end

    private

    def pagyd
      return if @pagy_details && @records

      @pagy_details, @records = ordered_scope.is_a?(Array) ? pagy_array(ordered_scope) : pagy(ordered_scope)
    end

    # Though this works, perhaps moving this in column(s) is nicer
    def order_hash(new_params = {})
      order_params = params[:order]&.permit!.to_h.symbolize_keys
      order_params.reject { |name, direction| direction.blank? }.to_h
                  .merge(new_params.symbolize_keys).reject { |name, direction| direction.blank? }
    end

  end
end