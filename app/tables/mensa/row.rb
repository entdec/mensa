# frozen_string_literal: true

module Mensa
  class Row
    attr_reader :table, :view_context, :record

    def initialize(table, record)
      @table = table
      @record = record
    end

    def value(column)
      if column.attribute && record.respond_to?(column.attribute)
        record.public_send(column.attribute)
      elsif column.method && record.respond_to?(column.method)
        record.public_send(column.method)
      elsif record.respond_to?(column.name)
        record.public_send(column.name)
      elsif record.respond_to?(:[])
        record[column.name]
      else
        "-"
      end
    end

    def link_attributes
      return {} unless link

      {href: link, data: {controller: "mensa-link", action: "click->mensa-link#follow tap->mensa-link#follow"}}
    end

    def link
      return unless table.link

      append_navigation_context(table.original_view_context.instance_exec(record, &table.link))
    end

    private

    def append_navigation_context(url)
      return url if url.blank?

      uri = URI.parse(url)
      existing_query = Rack::Utils.parse_nested_query(uri.query)
      merged_query = table.navigation_context.deep_stringify_keys.deep_merge(existing_query)
      query_string = merged_query.to_query
      uri.query = query_string.presence
      uri.to_s
    rescue URI::InvalidURIError
      url
    end
  end
end
