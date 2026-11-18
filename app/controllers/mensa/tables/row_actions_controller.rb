# frozen_string_literal: true

module Mensa
  module Tables
    class RowActionsController < ::ApplicationController
      def create
        table_name = params[:table_id]

        table = Mensa.for_name(table_name, params: Mensa::TableParams.from_request(params))
        table.original_view_context = helpers

        action = table.actions.find { |a| a.name == params[:name]&.to_sym && a.process? }
        return head :not_found unless action

        # Only records the table shows, and only when it shows the action
        record = table.scope.find_by(table.model.primary_key => params[:record_id])
        return head :not_found unless record && action.show.call(record)

        action.process.call(record)

        redirect_back_or_to helpers.mensa.table_path(table_name), status: :see_other
      end
    end
  end
end
