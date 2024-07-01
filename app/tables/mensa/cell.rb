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
        send("to_#{format}".to_sym)
      end
    end

    private

    def to_html
      case value
      when NilClass
        ''
      when TrueClass
        content_tag(:i, '', class: 'fa-regular fa-check')
      when FalseClass
        content_tag(:i, '', class: 'fa-regular fa-xmark')
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
