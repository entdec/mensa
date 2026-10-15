# frozen_string_literal: true

module Mensa
  class Row
    attr_reader :table, :view_context, :record

    def initialize(table, record)
      @table = table
      @record = record
    end

    # A model method is only called when the column asks for one with
    # `method`, otherwise the value is what was selected under the column's
    # name, so a model method with the same name doesn't shadow it
    def value(column)
      if column.value_method
        record.public_send(column.value_method)
      elsif record.has_attribute?(column.name)
        record[column.name]
      end
    end

    # The value of the group column, when the table is grouped
    def group_value
      record[Mensa::Grouping::GROUP_VALUE_ALIAS] if record.respond_to?(:has_attribute?) && record.has_attribute?(Mensa::Grouping::GROUP_VALUE_ALIAS)
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
