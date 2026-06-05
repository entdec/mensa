require "csv"
require "securerandom"
require "stringio"

module Mensa
  # Generates the CSV for a Mensa::Export, attaches it to the export's +asset+
  # and broadcasts the refreshed export button badge and downloads list so the
  # requesting user sees the finished download appear without reloading.
  class ExportJob < ApplicationJob
    queue_as :default

    def perform(export_id)
      export = Mensa::Export.find_by(id: export_id)
      return unless export

      export.update(status: "processing")
      Mensa.config.callbacks[:export_started]&.call(export)

      table = build_table(export)
      unless table.exportable?
        finalize(export, status: "failed")
        return
      end

      data, filename, content_type = generate(table, export)

      export.asset.attach(io: StringIO.new(data), filename: filename, content_type: content_type)
      finalize(export, status: "completed", filename: filename)

      Mensa.config.callbacks[:export_complete]&.call(export)
    rescue => e
      Mensa.config.logger&.error("Mensa::ExportJob failed for export #{export_id}: #{e.class}: #{e.message}")
      finalize(export, status: "failed") if export
      raise
    end

    private

    # Rebuilds the table the export was requested for, layering the view
    # configuration (if any) underneath the captured request configuration
    # (filters, query, ordering, page) so the generated data matches what the
    # user saw when they requested the export.
    def build_table(export)
      config = {}

      if export.table_view_id.present?
        view = Mensa::TableView.find_by(table_name: export.table_name, id: export.table_view_id)
        config = view.config.deep_symbolize_keys if view&.config
      end

      config = config.merge((export.config.compact_blank || {}).deep_symbolize_keys)
      table = Mensa.for_name(export.table_name, config)
      table.request = ActionDispatch::Request.new({})
      table.request.set_header("action_dispatch.request.query_parameters", {"page" => config[:page]})
      table
    end

    def generate(table, export)
      io = StringIO.new
      # A UTF-8 BOM makes spreadsheet programs such as Excel detect the encoding
      # correctly. The "plain" CSV variant omits it for maximum compatibility
      # with programmatic consumers.
      io.write("\uFEFF") if export.format == "csv_excel"

      csv = CSV.new(io)
      csv << table.display_columns.map(&:name)
      export_rows(table, export).each do |row|
        csv << table.display_columns.map { |column| row.value(column) }
      end
      io.rewind
      data = io.read

      base_filename = "#{export.table_name}_export_#{export.created_at.strftime("%Y-%m-%d-%H%M%S")}"

      if table.export_with_password?
        require "zip"
        password = SecureRandom.hex(6)
        encrypter = Zip::TraditionalEncrypter.new(password)
        zip_io = Zip::OutputStream.write_buffer(encrypter: encrypter) do |zio|
          zio.put_next_entry("#{base_filename}.csv")
          zio.write data
        end
        zip_io.rewind
        [zip_io.read, "#{base_filename}.zip", "application/zip"]
      else
        [data, "#{base_filename}.csv", "text/csv"]
      end
    end

    def export_rows(table, export)
      return table.ordered_scope.map { |row| Mensa::Row.new(table, row) } unless export.scope == "current_page"

      table.paged_scope.map { |row| Mensa::Row.new(self, row) }
    end

    def finalize(export, status:, filename: nil)
      attributes = {status: status}
      attributes[:filename] = filename if filename
      export.update(attributes)
      # Refresh the export button badge (download count) and the downloads list
      # inside the export dialog for everyone viewing this table.
      Mensa::Export.broadcast_refresh(export.table_name, export.user)
    end
  end
end
