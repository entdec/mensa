# frozen_string_literal: true

module Mensa
  class Row
    attr_reader :table, :view_context, :record

    def initialize(table, view_context, record)
      @table = table
      @view_context = view_context
      @record = record
    end

    def link_attributes
      {href: link, data: { controller: "satis-link",  action: "click->satis-link#follow tap->satis-link#follow" } }
    end

    def link
      view_context.instance_exec(record, &table.config[:link])
    end
  end
end