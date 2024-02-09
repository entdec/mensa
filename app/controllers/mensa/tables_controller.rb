module Mensa
  class TablesController < ::ApplicationController
    layout :decide_layout
    def show
      # TODO: Sanitize params
      @table = Mensa.for_name(params[:id], params.permit!.to_h)
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
