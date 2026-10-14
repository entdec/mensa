# frozen_string_literal: true

module Mensa
  class Verifier
    # One verified aspect of a table, e.g. sorting a column descending.
    #
    # +section+ groups checks in the report (:loads, :columns, :filters, ...),
    # +subject+ is the column, filter or view it relates to.
    Check = Struct.new(:section, :subject, :name, :status, :message, :sql, :error) do
      def passed?
        status == :passed
      end

      def failed?
        status == :failed
      end

      def skipped?
        status == :skipped
      end

      def label
        [subject, name].compact.join(": ")
      end
    end

    class Result
      SECTIONS = {
        loads: "Loads",
        columns: "Columns",
        filters: "Filters",
        search: "Search",
        render: "Rendering",
        exports: "Exports",
        grouping: "Grouping",
        views: "Views"
      }.freeze

      SYMBOLS = {passed: "✓", failed: "✗", skipped: "-"}.freeze

      attr_reader :table_class, :checks

      def initialize(table_class)
        @table_class = table_class
        @checks = []
      end

      # False for a class that isn't a Mensa::Base subclass, which is skipped
      def mensa_table?
        table_class.is_a?(Class) && table_class < Mensa::Base
      end

      def success?
        failures.empty?
      end

      def failures
        checks.select(&:failed?)
      end

      def passes
        checks.select(&:passed?)
      end

      def skips
        checks.select(&:skipped?)
      end

      def summary
        "#{passes.size} passed, #{failures.size} failed, #{skips.size} skipped"
      end

      def to_s
        return "#{table_class}\n  - skipped: #{checks.first&.message}" unless mensa_table?

        lines = [(table_class.name || table_class).to_s]

        checks.group_by(&:section).each do |section, section_checks|
          lines << "  #{SECTIONS.fetch(section, section.to_s.humanize)}"
          section_checks.each do |check|
            lines << "    #{SYMBOLS[check.status]} #{check.label}#{" (skipped: #{check.message})" if check.skipped?}"
            next unless check.failed?

            check.message.to_s.each_line { |line| lines << "        #{line.chomp}" }
            lines << "        SQL: #{check.sql}" if check.sql.present?
          end
        end

        lines << ""
        lines << "#{success? ? "OK" : "FAILED"}: #{summary}"
        lines.join("\n")
      end
      alias_method :report, :to_s

      def inspect
        "#<#{self.class.name} #{table_class} #{summary}>"
      end
    end
  end
end
