module Mensa
  class TablesController < ::ApplicationController
    layout :decide_layout

    def show
      config = if params[:table_view_id]
                 @view = Mensa::TableView.find_by(id: params[:table_view_id])
                 @view&.data || {}
               else
                 {}
               end

      # TODO: Sanitize params
      config = config.merge(params.permit!.to_h)

      @table = Mensa.for_name(params[:id], config)
      @table.name = params[:id]
      respond_to do |format|
        format.turbo_stream
        format.html
      end
    end

    def decide_layout
      return false if params[:turbo_frame_id]
    end
  end
end
