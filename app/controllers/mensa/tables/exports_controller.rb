module Mensa
  module Tables
    # Lists a user's available downloads for a table and creates new export
    # requests. Generating the CSV happens asynchronously in Mensa::ExportJob;
    # both the export button badge and the downloads list are refreshed via
    # Turbo streams once the job completes.
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
          config: params.permit(:query, :page, order: {}, filters: {}).to_h,
          status: "pending"
        )

        if export.save
          Mensa::ExportJob.perform_later(export.id)

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

      # Streams the generated CSV and then removes the export, purging the
      # attached asset. Downloads are single-use: routing them through the
      # controller (instead of a direct Active Storage link) gives us a hook to
      # delete the Mensa::Export record and free the stored file afterwards.
      def download
        export = exports.find(params[:id])
        return head :not_found unless export.downloadable?

        data = export.asset.download
        filename = export.asset.filename.to_s.presence || export.filename.presence || "#{export.table_name}_export.csv"
        content_type = export.asset.content_type.presence || "text/csv"

        send_data data, filename: filename, type: content_type, disposition: "attachment"

        # Clean up after a successful send. `has_one_attached :asset` purges the
        # blob when the record is destroyed (dependent: :purge_later). Never let
        # cleanup failures break the download itself.
        begin
          export.destroy
          Mensa::Export.broadcast_refresh(export.table_name, export.user)
        rescue => e
          Mensa.config.logger&.warn("Mensa::Export cleanup failed for #{export.id}: #{e.class}: #{e.message}")
        end
      end

      private

      def exports
        @exports ||= Mensa::Export.for_table(params[:table_id]).for_user(current_mensa_user).recent
      end

      def list_stream
        turbo_stream.replace(Mensa::Export.list_dom_id(params[:table_id], current_mensa_user),
          partial: "mensa/exports/list", locals: list_locals)
      end

      def badge_stream
        turbo_stream.replace(Mensa::Export.badge_dom_id(params[:table_id], current_mensa_user),
          partial: "mensa/exports/badge",
          locals: {table_name: params[:table_id], user: current_mensa_user})
      end

      def list_locals
        {table_name: params[:table_id], user: current_mensa_user, exports: exports}
      end

      def current_mensa_user
        Current.user if defined?(Current) && Current.respond_to?(:user)
      end
    end
  end
end
