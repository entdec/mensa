# frozen_string_literal: true

module Mensa
  class Cell
    include ActionView::Helpers::SanitizeHelper
    include ::ApplicationHelper
    include ActionView::Helpers::TagHelper
    include ActionView::Helpers::UrlHelper
    include Rails.application.routes.url_helpers

    attr_reader :column, :row

    def initialize(row:, column:)
      @row = row
      @column = column
    end

    def value
      @value ||= row.value(column)
    end

    def render(format)
      proc = column.config.dig(:render, format.to_sym)
      if proc
        row.table.original_view_context.instance_exec(row.record, &proc)
      else
        send(:"to_#{format}")
      end
    end

    private

    def to_html
      case value
      when NilClass
        ""
      when TrueClass
        content_tag(:i, "", class: "fa-solid fa-check")
      when FalseClass
        content_tag(:i, "", class: "fa-solid fa-xmark")
      when Array
        value.to_fs(:db)
      when Date
        I18n.l(value.in_time_zone(column.format.time_zone), format: column.format.format)
        # value.in_time_zone(column.format.time_zone).to_fs(column.format.format)
      when Time, DateTime
        I18n.l(value.in_time_zone(column.format.time_zone), format: column.format.format)
        # value.in_time_zone(column.format.time_zone).to_fs(column.format.format)
      else
        column.sanitize? ? sanitize(value.to_s) : value.to_s.html_safe
      end
    end

    def to_csv
      case value
      when NilClass
        ""
      when TrueClass, FalseClass
        value.to_s
      when Date
        I18n.l(value.in_time_zone(column.format.time_zone), format: column.format.format)
      when Time, DateTime
        value.in_time_zone(column.format.time_zone).to_fs(column.format.format)
      else
        strip_tags(value.to_s)
      end
    end
  end
end
