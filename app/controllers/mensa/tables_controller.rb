module Mensa
  class TablesController < ::ApplicationController
    def show
      @table = Mensa::Base.for_name(params[:id], params)
      render :show
    end
  end
end