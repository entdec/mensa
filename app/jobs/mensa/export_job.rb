module Mensa
  class ExportJob < ApplicationJob
    queue_as :default

    # export_started: lambda do |user_id, table_name|
    # end,
    # export_complete: lambda do |user_id, table_name, attachment|
    # end

    def perform(user_id, table_name)
      table = Mensa.for_name(table_name)
      context = Mensa.config.callbacks[:export_started].call(user_id, table_name)

      styles = []
      default_style = { b: true, bg_color: '3B82F6', fg_color: 'FFFFFF', border: { style: :thin, color: '000000' }, sz: 8,
                        alignment: { vertical: :bottom, horizontal: :left } }

      p = Axlsx::Package.new
      p.use_shared_strings = true

      wb = p.workbook

      wrap_text = wb.styles.add_style({ format_code: "@", alignment: { horizontal: :left, vertical: :top, wrap_text: true } })
      nowrap_text = wb.styles.add_style({ format_code: "@", alignment: { horizontal: :left, vertical: :top, wrap_text: false } })
      number_format = wb.styles.add_style format_code: '#'
      datetime_format = wb.styles.add_style format_code: "dddd, d mmmm yyyy hh:mm:ss"
      date_format = wb.styles.add_style format_code: "dddd, d mmmm yyyy"

      # custom_styles = ActionTable.config.format_config.each_with_object({}) { |(key, value), hash| hash[key] = value[:xlsx_style] if value.key?(:xlsx_style) }
      custom_style = {}

      wb.add_worksheet(name: table_name.first(31)) do |sheet|
        column_widths = []
        # TODO: Separate display columns for export?
        table.display_columns.map.with_index do |column, index|
          styles[index] = sheet.styles.add_style(default_style) #.merge(column.export_style || {}))
          # width = column.export_style.delete(:width)
          # column_widths[index] = width if width
        end

        first_row = sheet.add_row(table.display_columns.map { |c| c.human_name }, style: styles, height: 28)

        first_cell = first_row.first
        last_row = first_row

        table.export_rows.each do |row|
          # next if row.reject { |column, value| value.nil? || value == '' }.blank?
          #
          # row_types = :string #row.map(&:second)
          # row_values = row.map(&:third)
          # options = row.map(&:last)
          #
          # row_styles = options.map.with_index { |option, i|
          #   type = row_types[i]
          #   value = row_values[i]
          #   export_style = option.dig(:export, :xlsx_style)
          #
          #   if export_style.present?
          #     wb.styles.add_style(export_style)
          #   elsif custom_styles[type].present?
          #     wb.styles.add_style(custom_styles[type])
          #   elsif [:integer, :float, :decimal, :number].include?(type)
          #     number_format
          #   elsif [:datetime, :time, :timestamp].include?(type)
          #     datetime_format
          #   elsif type == :date
          #     date_format
          #   elsif value.is_a?(Axlsx::RichText) || type == :text
          #     wrap_text
          #   else
          #     nowrap_text
          #   end
          # }
          values = table.display_columns.map { |column| row.value(column) }
          row_styles = table.display_columns.map { |column| nowrap_text }
          last_row = sheet.add_row(values, style: row_styles)
        end

        last_cell = last_row.last

        sheet.column_widths(*column_widths)
        sheet.auto_filter = Axlsx.cell_range([first_cell, last_cell], false)
      end

      attachment = { io: p.to_stream,
                     content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', filename: "#{table_name}_export_#{Time.current.strftime("%Y-%m-%d-%H:%M:%S")}.xlsx" }

      Mensa.config.callbacks[:export_completed].call(user_id, table_name, context, attachment)
    end
  end
end
