# frozen_string_literal: true

module Mensa
  module RowAction
    class Component < ::Mensa::ApplicationComponent
      with_collection_parameter :action

      attr_reader :table
      attr_reader :row
      attr_reader :action

      def initialize(table:, row:, action:)
        @table = table
        @row = row
        @action = action
      end

      def href
        if action.process?
          # A Turbo POST link rather than button_to, a table can be inside a host form
          table.path_with_params(helpers.mensa.table_row_action_path(table.name, action.name, row.record.id))
        elsif action.link
          table.original_view_context.instance_exec(row.record, &action.link)
        else
          ""
        end
      end

      def attributes
        attributes = action.link_attributes || {}
        action.process? ? {data: {turbo_method: :post}}.deep_merge(attributes) : attributes
      end
    end
  end
end
