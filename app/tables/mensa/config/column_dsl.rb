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
    option :internal

    option :visible, default: :true
    dsl_option :render, Mensa::Config::RenderDsl
    dsl_option :filter, Mensa::Config::FilterDsl
  end
end
