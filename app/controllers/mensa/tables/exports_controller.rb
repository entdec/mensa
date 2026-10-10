module Mensa
  module Tables
    # Lists a user's available downloads for a table and creates new export
    # requests. Generating the CSV happens asynchronously in Mensa::ExportJob;
    # both the export button badge and the downloads list are refreshed via
    # Turbo streams once the job completes.
    #
    # Tables built with extra params send them along as params[...] in the
    # exports URL. They are stored on the export so Mensa::ExportJob can
    # rebuild the table, and they scope the downloads list and badge.
    class ExportsController < ::ApplicationController
      # Returns the current downloads list for the table, used to refresh the
      # contents of the export dialog when it is opened.
      def index
        respond_to do |format|
          format.turbo_stream { render turbo_stream: list_stream }
          format.html { render partial: "mensa/exports/list", locals: list_locals }
        end
      end

      # Creates a new export for the current user and enqueues the job that
      # generates and attaches the CSV.
      def create
        export = Mensa::Export.new(
          table_name: params[:table_id],
          table_view_id: params[:table_view_id].presence,
          user: current_mensa_user,
          format: params[:export_format].to_s.presence_in(Mensa::Export::FORMATS) || "csv_excel",
          scope: params[:scope].to_s.presence_in(Mensa::Export::SCOPES) || "all",
          repeat: params[:repeat].to_s.presence_in(Mensa::Export::REPEATS) || "",
          config: export_config,
          status: "pending"
        )

        if export.save
          Mensa::ExportJob.set(wait: 3.seconds).perform_later(export)

          respond_to do |format|
            format.turbo_stream { render turbo_stream: [list_stream, badge_stream] }
            format.json { render json: {id: export.id}, status: :created }
          end
        else
          respond_to do |format|
            format.turbo_stream { head :unprocessable_entity }
            format.json { render json: {errors: export.errors.full_messages}, status: :unprocessable_entity }
          end
        end
      end

      # Deletes an export from the current user's download list. The attached
      # asset is purged automatically when the record is destroyed.
      def destroy
        export = user_exports.find(params[:id])
        @table_params = export.table_params
        export.destroy
        Mensa::Export.broadcast_refresh(export.table_name, export.user, params: export.table_params)

        respond_to do |format|
          format.turbo_stream { render turbo_stream: [list_stream, badge_stream] }
          format.json { head :no_content }
          format.html { redirect_back fallback_location: mensa.table_exports_path(params[:table_id]) }
        end
      end

      # Streams the generated CSV and then removes the export, purging the
      # attached asset. Downloads are single-use: routing them through the
      # controller (instead of a direct Active Storage link) gives us a hook to
      # delete the Mensa::Export record and free the stored file afterwards.
      def download
        export = user_exports.find(params[:id])
        return head :not_found unless export.downloadable?

        data = export.asset.download
        filename = export.asset.filename.to_s.presence || export.filename.presence || "#{export.table_name}_export.csv"
        content_type = export.asset.content_type.presence || "text/csv"

        send_data data, filename: filename, type: content_type, disposition: "attachment"

        # One-off exports are single-use and are deleted after download.
        # Repeating exports stay in place and can be removed explicitly via the
        # trash action.
        begin
          if export.repeating?
            export.asset.purge_later
          else
            export.destroy
          end
          Mensa::Export.broadcast_refresh(export.table_name, export.user, params: export.table_params)
        rescue => e
          Mensa.config.logger&.warn("Mensa::Export cleanup failed for #{export.id}: #{e.class}: #{e.message}")
        end
      end

      private

      # All of the current user's exports of this table, regardless of
      # params. Download and delete links don't carry the params.
      def user_exports
        Mensa::Export.where(table_name: params[:table_id]).for_user(current_mensa_user)
      end

      # The exports listed for the table as built with the current params.
      def exports
        @exports ||= Mensa::Export.for_table(params[:table_id], params: table_params).for_user(current_mensa_user).recent
      end

      def table_params
        @table_params ||= Mensa::TableParams.from_request(params)
      end

      def list_stream
        turbo_stream.replace(Mensa::Export.list_dom_id(params[:table_id], current_mensa_user, params: table_params),
          partial: "mensa/exports/list", locals: list_locals)
      end

      def badge_stream
        turbo_stream.replace(Mensa::Export.badge_dom_id(params[:table_id], current_mensa_user, params: table_params),
          partial: "mensa/exports/badge",
          locals: {table_name: params[:table_id], user: current_mensa_user, table_params: table_params})
      end

      def list_locals
        {table_name: params[:table_id], user: current_mensa_user, table_params: table_params, exports: exports}
      end

      def export_config
        config = params.permit(
          :query,
          :page,
          :table_view_id,
          :group_by,
          order: {},
          filters: {},
          column_order: [],
          hidden_columns: [],
          params: {}
        ).to_h
        config.delete(:params)
        config[:params] = table_params if table_params.present?
        config
      end

      def current_mensa_user
        Current.user if defined?(Current) && Current.respond_to?(:user)
      end
    end
  end
end
