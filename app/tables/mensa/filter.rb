# frozen_string_literal: true

module Mensa
  class Filter
    include ConfigReaders

    defined_by Mensa::Config::FilterDsl

    attr_reader :column, :table

    config_reader :operator, cast: :to_sym
    config_reader :value
    config_reader :scope
    config_reader :multiple

    class << self
      def OPERATORS
        [
          [:equals, I18n.t("operators.equals", scope: :mensa), true],
          [:not_equals, I18n.t("operators.not_equals", scope: :mensa), true],
          [:contains, I18n.t("operators.contains", scope: :mensa), true],
          [:is_current, I18n.t("operators.is_current", scope: :mensa), false]
        ].freeze
      end
    end

    def initialize(column:, config:, table:)
      @column = column
      @config = self.class.definition.merge(config || {})
      @table = table
    end

    def multiple?
      !!multiple
    end

    def collection
      return unless config&.key?(:collection)

      if config[:collection].is_a? Proc
        table.original_view_context.instance_exec(&config[:collection])
      else
        config[:collection]
      end
    end

    # This defines how the filter should be displayed in the value popover
    # :select => as a select input
    # :checkbox => as a checkbox input
    # :string => as a text input
    def as
      config[:as]
    end

    def to_s
      parts = [column.human_name, operator_label]
      formatted_value = value.is_a?(Array) ? value.join(", ") : value
      parts << formatted_value if formatted_value.present? && operator_with_value?
      parts.join(" ")
    end

    def filter_scope(record_scope)
      if scope
        record_scope.instance_exec(normalize(value), &scope)
      else
        case operator
        when :is_current
          record_scope.where("#{column.attribute_for_condition} = ?", Current.send(column.name))
        when :contains
          record_scope.where("#{column.attribute_for_condition} LIKE ?", "%#{normalize(value)}%")
        when :equals
          val = value.is_a?(Array) ? value : normalize(value)
          record_scope.where(column.attribute_for_condition => val)
        when :not_equals
          val = value.is_a?(Array) ? value : normalize(value)
          record_scope.where.not(column.attribute_for_condition => val)
        else
          # Ignore unknown operators
          record_scope
        end
      end
    end

    def operators
      return config[:operators] if config[:operators].present?

      operators = Mensa::Filter.OPERATORS.dup
      operators.delete_if { |op| op[0] == :is_current } unless Current.methods.include?(column.name)
      operators
    end

    def operator_label
      Mensa::Filter.OPERATORS.find { |op| op[0] == operator }[1]
    end

    def operator_with_value?
      Mensa::Filter.OPERATORS.find { |op| op[0] == operator }[2]
    end

    private

    def normalize(query)
      query.to_s.gsub(/\s(?![&!|])/, '\\\\ ')
    end
  end
end
