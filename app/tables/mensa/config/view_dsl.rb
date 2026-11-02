module Mensa::Config
  class ViewDsl
    include DslLogic

    option :name
    option :description
    option :filter, dsl_hash: Mensa::Config::FilterDsl
    option :column_order
    option :hidden_columns
    option :group_by
    option :aggregates

    def initialize(name, partials: {}, &)
      @partials = partials
      super(name, &)
    end

    # Applies a partial, defined in the table with `partial :name do ... end`,
    # or a block, as if its contents were written here. What follows the
    # include overrides it, e.g. a filter on the same column.
    #
    #   view :sales_orders do
    #     include :open
    #   end
    def include(partial)
      block = partial.is_a?(Proc) ? partial : @partials[partial.to_sym]
      raise ArgumentError, "Unknown view partial #{partial.inspect}, define it with `partial #{partial.inspect} do ... end` before the views that include it" unless block

      instance_exec(&block)
    end
  end
end
