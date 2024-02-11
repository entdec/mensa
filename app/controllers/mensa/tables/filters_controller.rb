module Mensa
  module Tables
    class FiltersController < ::ApplicationController
      layout false

      def show
        # TODO: Sanitize params
        @table = Mensa.for_name(params[:table_id], params.permit!.to_h)
        @table.name = params[:id]
        respond_to do |format|
          format.turbo_stream
          format.html
        end
      end
    end
  end
end
