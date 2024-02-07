# frozen_string_literal: true

module Mensa::Config
  class ColumnDsl
    include DslLogic

    option :sortable, default: true
    option :sanitize, default: true
    option :attribute
    dsl_option :render, Mensa::Config::RenderDsl
  end
end
