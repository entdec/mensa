# frozen_string_literal: true

module Mensa
  module TableRow
    class Component < ::Mensa::ApplicationComponent
      with_collection_parameter :row

      include TablesHelper

      attr_reader :table
      attr_reader :row
      attr_reader :group

      def initialize(table:, row:, group: nil)
        @table = table
        @row = row
        @group = group
      end

      def row_attributes
        return row.link_attributes unless group

        row.link_attributes.deep_merge(data: {mensa_groups_target: "row", group_key: group.key})
      end
    end
  end
end
