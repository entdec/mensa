module Mensa
  module Tables
    class FiltersController < ::ApplicationController
      layout false

      class Filter
        include ActiveModel::Model
        attr_accessor :value
      end

      def index
        config = {}.merge(params.permit(:id, :page, :table_id, :target, :table_view_id, :turbo_frame_id, order: {}, filters: {}).to_h)
        @table = Mensa.for_name(params[:table_id], config)
      end

      def show
        config = {}.merge(params.permit(:id, :page, :table_id, :target, :table_view_id, :turbo_frame_id, order: {}, filters: {}).to_h)
        @table = Mensa.for_name(params[:table_id], config)
        @table.original_view_context = helpers
        @column = @table.column(params[:id])
        respond_to do |format|
          format.turbo_stream
          format.html
        end
      end
    end
  end
end
