# frozen_string_literal: true

module Mensa
  module Tables
    class BatchActionsController < ::ApplicationController
      def create
        table_name = params[:table_id]
        batch_action_name = params[:batch_action_name]&.to_sym
        record_ids = Array(params[:record_ids])

        table = Mensa.for_name(table_name)
        table.original_view_context = helpers

        batch_action = table.batch_actions.find { |a| a.name == batch_action_name }
        return head :not_found unless batch_action

        records = table.model.where(id: record_ids).to_a
        batch_action.process.call(records)

        redirect_back_or_to helpers.mensa.table_path(table_name)
      end
    end
  end
end
