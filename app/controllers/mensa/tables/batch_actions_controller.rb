# frozen_string_literal: true

module Mensa
  module Tables
    # Runs batch actions on the selected records: the checked rows
    # (record_ids[]), or every row matching the table's current search and
    # filters (select_all). Either way only records in the table's scope.
    #
    # Batch actions with a form first show it in a dialog, which is loaded
    # from #new into the mensa-batch-dialog turbo-frame.
    class BatchActionsController < ::ApplicationController
      DIALOG_FRAME = "mensa-batch-dialog"

      before_action :set_batch_action

      def new
        return head :not_found unless @batch_action.form?

        @batch = Mensa::Batch.new(table: @table, action: @batch_action, user: current_mensa_user, count: params[:count].to_i)
        render :new, layout: false
      end

      def create
        @batch = Mensa::Batch.new(table: @table, action: @batch_action, records: selected_records, params: batch_params, user: current_mensa_user)
        @batch_action.perform(@batch, helpers)

        if @batch.errors.none? && @batch.redirect_url
          redirect_to @batch.redirect_url, **@batch.flash, status: :see_other
        elsif @batch.errors.none?
          redirect_back_or_to helpers.mensa.table_path(@table.name), **@batch.flash, status: :see_other
        elsif dialog_request?
          render :new, layout: false, status: :unprocessable_entity
        else
          redirect_back_or_to helpers.mensa.table_path(@table.name), alert: @batch.errors.full_messages.to_sentence, status: :see_other
        end
      end

      private

      def set_batch_action
        @table = Mensa.for_name(params[:table_id], table_config)
        @table.request = request
        @table.original_view_context = helpers

        @batch_action = @table.batch_actions.find { |a| a.name == params[:batch_action_name]&.to_sym }
        return head :not_found unless @batch_action

        head :forbidden unless @batch_action.show?(helpers)
      end

      # The table as the user saw it: the view's configuration, with the
      # search and filters sent along on top (like Mensa::TablesController)
      def table_config
        filters_provided = params.key?(:filters)
        config = params.permit(:query, :table_view_id, filters: {}).to_h
        config[:filters] = {} if filters_provided && !config.key?(:filters)
        config[:params] = Mensa::TableParams.from_request(params)

        view = Mensa::TableView.find_by(table_name: params[:table_id], id: params[:table_view_id]) if params[:table_view_id].present?
        (view&.config&.deep_symbolize_keys || {}).merge(config.deep_symbolize_keys)
      end

      # Selected through the table's scope by id, so joins in it can't repeat
      # records and its select or grouping don't end up in the relation
      def selected_records
        model = @table.model
        key = model.primary_key
        source = params[:select_all].present? ? @table.filtered_scope : @table.scope.where(key => Array(params[:record_ids]))

        model.where(key => source.unscope(:order, :limit, :offset).reselect(model.arel_table[key]))
      end

      # The dialog's fields, which its form submits under batch[...]
      def batch_params
        params.fetch(:batch, ActionController::Parameters.new)
      end

      def dialog_request?
        request.headers["Turbo-Frame"] == DIALOG_FRAME
      end

      def current_mensa_user
        Current.user if defined?(Current) && Current.respond_to?(:user)
      end
    end
  end
end
