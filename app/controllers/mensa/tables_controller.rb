module Mensa
  class TablesController < ::ApplicationController
    layout :decide_layout

    def index
      render layout: 'mensa/application'
    end

    def show
      config = if params[:table_view_id]
                 @view = Mensa::TableView.find_by(table_name: params[:id], id: params[:table_view_id])
                 @view&.data || {}
               else
                 {}
               end

      config = config.merge(params.permit!.to_h)
      config = config.merge(params.permit(:format, :query, :id, :page, :table_view_id, :turbo_frame_id, order: {}, filters: {}).to_h)

      @table = Mensa.for_name(params[:id], config)
      @table.table_view = @view
      @table.original_view_context = helpers

      respond_to do |format|
        format.turbo_stream
        format.html
        format.xlsx do
          Mensa::ExportJob.perform_later(current_user, params[:id])
          head 200
        end
      end
    end

    def decide_layout
      return false if params[:turbo_frame_id]
    end
  end
end
