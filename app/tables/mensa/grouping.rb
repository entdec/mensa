# frozen_string_literal: true

module Mensa
  # Shows rows in groups: rows are sorted by the group column and every group
  # gets a header with its row count and the chosen aggregates. Counts and
  # aggregates are calculated with SQL GROUP BY over all filtered rows, not
  # just the current page.
  module Grouping
    extend ActiveSupport::Concern

    GROUP_VALUE_ALIAS = "mensa_group_value"

    # The column the rows are grouped by, nil when not grouped
    def group_column
      return @group_column if defined?(@group_column)

      name = current_group_by
      col = column(name) if name.present?
      @group_column = (col if col&.groupable? && scope.is_a?(ActiveRecord::Relation))
    end

    def grouped?
      group_column.present?
    end

    def current_group_by
      config[:group_by].presence
    end

    # The chosen aggregates as {column_name => function}, skipping columns and
    # functions that don't allow it, e.g. from browser state saved earlier.
    def current_aggregates
      @current_aggregates ||= (config[:aggregates].presence || {}).to_h.filter_map { |name, function|
        col = column(name)
        next unless col && !col.internal?

        function = col.aggregates.find { |f| f.to_s == function.to_s }
        [col.name, function] if function
      }.to_h
    end

    # All groups, keyed by group value
    def groups
      return {} unless grouped?

      @groups ||= calculate_groups
    end

    # The group a row belongs to
    def group_for(row)
      value = row.group_value
      groups[value] || Mensa::Group.new(table: self, value: value)
    end

    private

    def group_order_clause
      direction = (group_column.sort_direction == :desc) ? "desc" : "asc"
      "#{group_column.attribute_for_condition} #{direction} NULLS LAST"
    end

    def group_select
      Arel.sql("#{group_column.attribute_for_condition} AS #{GROUP_VALUE_ALIAS}")
    end

    # Runs the GROUP BY on a subquery of the filtered rows, so it also works
    # for scopes that have their own GROUP BY/HAVING and for aggregate
    # expressions as column attributes.
    def calculate_groups
      aggregates = current_aggregates.to_a
      relation = filtered_scope.except(:select, :order, :limit, :offset)

      inner_selects = [group_select]
      aggregates.each_with_index do |(name, _function), index|
        inner_selects << Arel.sql("#{column(name).attribute_for_condition} AS mensa_aggregate_#{index}")
      end

      outer_selects = ["mensa_groups.#{GROUP_VALUE_ALIAS}", "COUNT(*)"]
      aggregates.each_with_index do |(_name, function), index|
        outer_selects << "#{function.to_s.upcase}(mensa_groups.mensa_aggregate_#{index})"
      end

      rows = relation.model.unscoped
        .from(relation.select(*inner_selects), :mensa_groups)
        .group(Arel.sql("mensa_groups.#{GROUP_VALUE_ALIAS}"))
        .pluck(*outer_selects.map { |sql| Arel.sql(sql) })

      rows.to_h do |value, count, *aggregate_values|
        values = aggregates.map(&:first).zip(aggregate_values).to_h
        [value, Mensa::Group.new(table: self, value: value, count: count, aggregates: values)]
      end
    end
  end
end
