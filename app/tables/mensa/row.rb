# frozen_string_literal: true

module Mensa
  class Row
    attr_reader :table, :view_context, :record

    def initialize(table, view_context, record)
      @table = table
      @view_context = view_context
      @record = record
    end

    def value(column)
      if record.respond_to?(column.attribute)
        record.public_send(column.attribute)
      elsif record.respond_to?(:[])
        record[column.attribute]
      else
        "-"
      end
    end

    def link_attributes
      return {} unless link

      { href: link, data: { controller: "satis-link",  action: "click->satis-link#follow tap->satis-link#follow" } }
    end

    def link
      view_context.instance_exec(record, &table.link) if table.link
    end
  end
end
