# frozen_string_literal: true

module Mensa
  class Cell
    include ActionView::Helpers::SanitizeHelper
    include ::ApplicationHelper

    attr_reader :column, :row

    def initialize(row:, column:)
      @row = row
      @column = column
    end

    def value
      @value ||= row.value(column)
    end

    def to_html
      return column.config.dig(:render, :html).call(row.record) if column.config.dig(:render, :html)

      case value
      when NilClass
        ''
      when TrueClass
        '<i class="fa fa-check"></i>'.html_safe
      when FalseClass
        '<i class="fa fa-xmark"></i>'.html_safe
      when Date
        return dt(value) if respond_to?(:dt)

        value.strftime('%d.%m.%Y')
      when Time, DateTime
        return ln(value) if respond_to?(:ln)

        value.strftime('%d-%m-%Y %H:%M:%S')
      else
        return sanitize(value.to_s) if column.sanitize?

        value.to_s
      end
    end
  end
end
