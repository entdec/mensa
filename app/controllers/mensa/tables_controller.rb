module Mensa
  class TablesController < ::ApplicationController
    def show
      # TODO: Sanitize params
      @table = Mensa.for_name(params[:id], params.permit!.to_h)
      render :show
    end
  end
end
