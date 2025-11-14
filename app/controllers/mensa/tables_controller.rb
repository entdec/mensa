module Mensa
  class TablesController < ApplicationController
    def show
      @table = Mensa.for_name(params[:id])

      config = {}
      if params[:table_view_id]
        @view = Mensa::TableView.find_by(table_name: params[:id], id: params[:table_view_id])
        @view ||= @table.system_views.find { |v| v.id == params[:table_view_id].to_sym }
        config = @view&.config
      end

      config = config.merge(params.permit!.to_h)
      config = config.merge(params.permit(:format, :query, :id, :page, :table_view_id, :turbo_frame_id, order: {}, filters: {}).to_h)

      @table = Mensa.for_name(params[:id], config)
      @table.request = request
      @table.table_view = @view
      @table.original_view_context = helpers

      respond_to do |format|
        format.turbo_stream # Used for filterering
        format.html
        format.xlsx do
          Mensa::ExportJob.perform_later(current_user, params[:id])
          head :ok
        end
      end
    end
  end
end
