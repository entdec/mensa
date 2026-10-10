# frozen_string_literal: true

require "digest"

module Mensa
  # A group of rows in a grouped table, see Mensa::Grouping
  class Group
    attr_reader :table, :value, :count, :aggregates

    def initialize(table:, value:, count: nil, aggregates: {})
      @table = table
      @value = value
      @count = count
      @aggregates = aggregates
    end

    def column
      table.group_column
    end

    # Stable identifier for the group, used to remember collapsed groups
    def key
      value.nil? ? "none" : Digest::SHA256.hexdigest(value.to_s)[0, 12]
    end

    def title
      return I18n.t("mensa.groups.empty", column: column.human_name) if value.nil? || value == ""

      Mensa::Cell.new(row: nil, column: column, value: value).formatted
    end

    # The aggregate for a column, formatted for display, nil when there is none
    def aggregate(column)
      return unless aggregates.key?(column.name)

      value = aggregates[column.name]
      return ActiveSupport::NumberHelper.number_to_delimited(value) if value.is_a?(Numeric)

      Mensa::Cell.new(row: nil, column: column, value: value).formatted
    end

    def aggregate_label(column)
      function = table.current_aggregates[column.name]
      I18n.t("mensa.aggregates.#{function}") if function
    end
  end
end
