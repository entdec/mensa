module Mensa
  class TablesController < ApplicationController
    def show
      config = params.permit(:format, :query, :id, :page, :table_view_id, :turbo_frame_id, order: {}, column_order: [], hidden_columns: [], params: {}).to_h
      config[:filters] = params[:filters]&.to_unsafe_h || {}
      config[:params] = params[:params]&.to_unsafe_h || {}

      if params[:table_view_id]
        view_lookup_table = Mensa.for_name(params[:id], config)
        @view = Mensa::TableView.find_by(table_name: params[:id], id: params[:table_view_id])
        @view ||= view_lookup_table.system_views.find { |v| v.id == params[:table_view_id].to_sym }
        config = (@view&.config&.deep_transform_keys(&:to_sym) || {}).merge(config)
      end

      @table = Mensa.for_name(params[:id], config)
      @table.request = request
      @table.table_view = @view
      @table.original_view_context = helpers

      respond_to do |format|
        format.turbo_stream # Used for filtering
        format.html
      end
    end
  end
end
