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

    # Renders the cell's content in the given format. The :html format
    # includes the surrounding <td>; when a custom html render block returns
    # its own td (e.g. content_tag(:td, ..., class: ...)), that one is used.
    def render(format)
      content = render_content(format)
      return content unless format.to_sym == :html
      return content if td?(content)

      content_tag(:td, content)
    end

    private

    # Only HTML-safe output counts, so plain strings are still escaped.
    def td?(content)
      content.html_safe? && content.to_s.lstrip.match?(/\A<td[\s>]/i)
    end

    def render_content(format)
      proc = column.config.dig(:render, format.to_sym)
      if proc
        row.table.original_view_context.instance_exec(row.record, &proc)
      else
        send(:"to_#{format}")
      end
    end

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
