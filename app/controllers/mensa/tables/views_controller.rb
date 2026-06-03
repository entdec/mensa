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
          render json: {id: view.id, name: view.name}, status: :created
        else
          render json: {errors: view.errors.full_messages}, status: :unprocessable_entity
        end
      end

      private

      # The view configuration mirrors the query parameters the table reads on
      # show (query, ordering and filters), so a saved view can be replayed by
      # merging this hash back into the request params.
      def view_config
        params.permit(:query, order: {}, filters: {}).to_h
      end

      def current_mensa_user
        Current.user if defined?(Current) && Current.respond_to?(:user)
      end
    end
  end
end
