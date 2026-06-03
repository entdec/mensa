require "securerandom"

module Mensa
  class ExportJob < ApplicationJob
    queue_as :default

    def perform(to, table_name)
      table = Mensa.for_name(table_name)
      return unless table.exportable?

      context = Mensa.config.callbacks[:export_started].call(to, table_name)

      io = StringIO.new
      csv = CSV.new(io)
      csv << table.display_columns.map(&:human_name)
      table.export_rows.each { |r| csv << r }

      base_filename = "#{table_name}_export_#{Time.current.strftime("%Y-%m-%d-%H:%M:%S")}"
      enc = nil
      password = nil
      if table.export_with_password?
        password = SecureRandom.hex(6)
        enc = Zip::TraditionalEncrypter.new(password)
      end
      stringio = Zip::OutputStream.write_buffer(encrypter: enc) do |zio|
        zio.put_next_entry("#{base_filename}.csv")
        zio.write io.read
      end
      stringio.rewind

      attachment = {io: stringio,
                    content_type: "application/zip", filename: "#{base_filename}.zip"}
      if password.present?
        attachment[:password] = password
      end

      Mensa.config.callbacks[:export_completed].call(to, table_name, context, attachment)
    end
  end
end
