module Mensa
  class Base
    include Pagy::Backend

    attr_accessor :view_context
    attr_reader :params
    delegate :config, to: :class

    def initialize(params)
      @params = params
    end

    def columns
      @columns ||= config[:columns].map { |config| Mensa::Column.new(self, config) }
    end

    def model
      config[:model_class]
    end

    def scope
      model.all
    end

    def filtered_scope
      scope
    end

    def ordered_scope
      return @ordered_scope if @ordered_scope

      @ordered_scope = filtered_scope
    end

    # private
    def pagyd
      return if @pagy_details && @records

      @pagy_details, @records = ordered_scope.is_a?(Array) ? pagy_array(ordered_scope) : pagy(ordered_scope)
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
  end
end