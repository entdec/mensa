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

    def to_html
      return row.table.original_view_context.instance_exec(row.record, &column.config.dig(:render, :html)) if column.config.dig(:render, :html)

      case value
      when NilClass
        ''
      when TrueClass
        content_tag(:i, '', class: 'fa fa-check')
      when FalseClass
        content_tag(:i, '', class: 'fa fa-xmark')
      when Date
        respond_to?(:dt) ? dt(value) : value.strftime('%d.%m.%Y')
      when Time, DateTime
        respond_to?(:ln) ? ln(value) : value.strftime('%d-%m-%Y %H:%M:%S')
      else
        column.sanitize? ? sanitize(value.to_s) : value.to_s.html_safe
      end
    end
  end
end
