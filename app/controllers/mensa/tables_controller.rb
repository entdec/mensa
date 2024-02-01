module Mensa
  class TablesController < ::ApplicationController
    def show
      # TODO: Sanitize params
      @table = Mensa.for_name(params[:id], params.permit!.to_h)
      respond_to do |format|
        format.turbo_stream
        format.html
      end
    end
  end
end
