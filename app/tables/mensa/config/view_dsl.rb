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
  end
end
