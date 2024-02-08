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
    option :visible, default: :true
    dsl_option :render, Mensa::Config::RenderDsl
  end
end
