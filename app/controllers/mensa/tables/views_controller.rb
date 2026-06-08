module Mensa
  module Tables
    class ViewsController < ::ApplicationController
      # Persists the current filters, ordering and search query as a named
      # custom view, owned by the current user. Without a current user there is
      # nobody to own the view, so the request is rejected (and the UI hides the
      # save button in that case).
      def create
        user = current_mensa_user
        return head(:forbidden) if user.blank?

        view = Mensa::TableView.new(
          table_name: params[:table_id],
          name: params[:name],
          description: params[:description],
          config: view_config,
          user: user
        )

        if view.save
          respond_to do |format|
            format.turbo_stream do
              # Re-use the same turbo_frame_id that the client sent so the
              # generated element IDs match what is already in the DOM.
              table_config = view.config
                .deep_transform_keys(&:to_sym)
                .merge(turbo_frame_id: params[:turbo_frame_id])

              @table = Mensa.for_name(params[:table_id], table_config)
              @table.request = request
              @table.original_view_context = helpers
              @table.table_view = view
            end
            format.json { render json: {id: view.id, name: view.name}, status: :created }
          end
        else
          render json: {errors: view.errors.full_messages}, status: :unprocessable_entity
        end
      end

      def update
        user = current_mensa_user
        return head(:forbidden) if user.blank?

        view = Mensa::TableView.find_by(table_name: params[:table_id], id: params[:id], user: user)
        return head(:not_found) if view.blank?

        # When only renaming, preserve the existing config rather than overwriting
        # with an empty hash from view_config.
        new_config = view_config
        update_attrs = {config: new_config.present? ? new_config : view.config}
        update_attrs[:name] = params[:name] if params[:name].present?

        if view.update(update_attrs)
          respond_to do |format|
            format.turbo_stream do
              table_config = view.config
                .deep_transform_keys(&:to_sym)
                .merge(turbo_frame_id: params[:turbo_frame_id])

              @table = Mensa.for_name(params[:table_id], table_config)
              @table.request = request
              @table.original_view_context = helpers
              @table.table_view = view
            end
            format.json { render json: {id: view.id, name: view.name} }
          end
        else
          render json: {errors: view.errors.full_messages}, status: :unprocessable_entity
        end
      end

      def destroy
        user = current_mensa_user
        return head(:forbidden) if user.blank?

        view = Mensa::TableView.find_by(table_name: params[:table_id], id: params[:id], user: user)
        return head(:not_found) if view.blank?

        view.destroy

        respond_to do |format|
          format.turbo_stream do
            @table = Mensa.for_name(params[:table_id], {turbo_frame_id: params[:turbo_frame_id]})
            @table.request = request
            @table.original_view_context = helpers
          end
          format.json { head :no_content }
        end
      end

      private

      # The view configuration mirrors the query parameters the table reads on
      # show (query, ordering and filters), so a saved view can be replayed by
      # merging this hash back into the request params.
      def view_config
        config = params.permit(:query, order: {}, column_order: [], hidden_columns: []).to_h
        config[:filters] = params[:filters]&.to_unsafe_h || {}
        config
      end

      def current_mensa_user
        Current.user if defined?(Current) && Current.respond_to?(:user)
      end
    end
  end
end
