# frozen_string_literal: true

module Mensa::Config
  class ColumnDsl
    include DslLogic

    option :sortable, default: true
    option :sanitize, default: true
    # Allows for sql-parts too
    #
    #   attribute 'EXTRACT(YEAR FROM AGE(born_on))::int as age'
    #
    option :attribute
    # Internal columns will never be shown, but are there to be selected, to be used in methods
    # Mensa doesn't select the whole records, to only select what we need
    option :internal, default: false
    option :method
    option :type
    option :format, default: :long, dsl_single_hash: Mensa::Config::FormatDsl, name_attribute: :format

    option :visible, default: true
    # Allows the user to group the table by this column (needs an SQL attribute)
    option :groupable, default: false
    # Aggregates the user can choose for this column in grouped tables,
    # any of :count, :sum, :min and :max
    option :aggregates, default: []
    option :render, dsl: Mensa::Config::RenderDsl
    option :filter, dsl: Mensa::Config::FilterDsl

    #   aggregates :sum, :min, :max
    def aggregates(*functions)
      config[:aggregates] = functions.flatten.map(&:to_sym)
    end
  end
end
