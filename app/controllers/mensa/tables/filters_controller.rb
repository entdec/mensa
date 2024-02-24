module Mensa
  module Tables
    class FiltersController < ::ApplicationController
      layout false

      class Filter
        include ActiveModel::Model
        attr_accessor :value
      end

      def index
        @table = Mensa.for_name(params[:table_id], params.permit!.to_h)
      end

      def show
        # TODO: Sanitize params
        @table = Mensa.for_name(params[:table_id], params.permit!.to_h)
        respond_to do |format|
          format.turbo_stream
          format.html
        end
      end
    end
  end
end
