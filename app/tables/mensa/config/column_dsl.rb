# frozen_string_literal: true

module Mensa::Config
  class ColumnDsl
    include DslLogic

    option :sortable, default: true
    option :attribute
    option :render, dsl: Mensa::Config::RenderDsl
  end
end
