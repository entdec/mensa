require "csv"
require "securerandom"
require "tempfile"

module Mensa
  # Generates the CSV for a Mensa::Export, attaches it to the export's +asset+
  # and broadcasts the refreshed export button badge and downloads list so the
  # requesting user sees the finished download appear without reloading.
  class ExportJob < ApplicationJob
    queue_as :default

    def perform(export)
      return unless export

      export.update(status: "processing")
      Mensa.config.callbacks[:export_started]&.call(export)

      table = build_table(export)
      unless table.exportable?
        finalize(export, status: "failed")
        return
      end

      tempfile, filename, content_type = generate(table, export)

      export.asset.purge if export.asset.attached?
      export.asset.attach(io: tempfile, filename: filename, content_type: content_type)
      finalize(export, status: "completed", filename: filename)

      Mensa.config.callbacks[:export_complete]&.call(export)
    rescue => e
      Mensa.config.logger&.error("Mensa::ExportJob failed for export #{export&.id}: #{e.class}: #{e.message}")
      finalize(export, status: "failed") if export
      raise
    ensure
      tempfile&.close!
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
      base_filename = "#{export.table_name}_export_#{export.created_at.strftime("%Y-%m-%d-%H%M%S")}"
      csv_file = write_csv_file(table, export, base_filename)

      if table.export_with_password?
        zip_file = write_zip_file(csv_file, export, base_filename)
        csv_file.close!
        [zip_file, "#{base_filename}.zip", "application/zip"]
      else
        [csv_file, "#{base_filename}.csv", "text/csv"]
      end
    end

    def write_csv_file(table, export, base_filename)
      tempfile = Tempfile.new([base_filename, ".csv"], binmode: true)

      # A UTF-8 BOM makes spreadsheet programs such as Excel detect the encoding
      # correctly. The "plain" CSV variant omits it for maximum compatibility
      # with programmatic consumers.
      tempfile.write("\uFEFF") if export.format == "csv_excel"

      csv = CSV.new(tempfile)
      csv << table.display_columns.map(&:name)
      export_rows(table, export).each do |row|
        csv << table.display_columns.map { |column| Mensa::Cell.new(row: row, column: column).render(:csv) }
      end
      csv.close
      tempfile.open
      tempfile.binmode
      tempfile.rewind
      tempfile
    rescue
      tempfile&.close!
      raise
    end

    def write_zip_file(csv_file, export, base_filename)
      require "zip"

      zip_file = Tempfile.new([base_filename, ".zip"], binmode: true)
      zip_path = zip_file.path
      zip_file.close

      export.password = SecureRandom.hex(6)
      encrypter = Zip::TraditionalEncrypter.new(export.password)
      Zip::OutputStream.open(zip_path, encrypter: encrypter) do |zio|
        zio.put_next_entry("#{base_filename}.csv")
        csv_file.rewind
        IO.copy_stream(csv_file, zio)
      end

      zip_file.open
      zip_file.binmode
      zip_file.rewind
      zip_file
    rescue
      zip_file&.close!
      raise
    end

    def export_rows(table, export)
      scope = (export.scope == "current_page") ? table.paged_scope : table.selected_scope
      scope.map { |row| Mensa::Row.new(table, row) }
    end

    def finalize(export, status:, filename: nil)
      attributes = {status: status}
      attributes[:filename] = filename if filename

      attributes[:last_repeat_run_at] = Time.current if status == "completed" && export.repeat.present?

      export.update(attributes)
      # Refresh the export button badge (download count) and the downloads list
      # inside the export dialog for everyone viewing this table.
      Mensa::Export.broadcast_refresh(export.table_name, export.user)
    end
  end
end
