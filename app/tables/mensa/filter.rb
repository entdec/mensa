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
          [:is, I18n.t("mensa.operators.is"), true],
          [:isnt, I18n.t("mensa.operators.isnt"), true],
          [:matches, I18n.t("mensa.operators.matches"), true],
          [:does_not_match, I18n.t("mensa.operators.does_not_match"), true],
          [:is_current, I18n.t("mensa.operators.is_current"), false]
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
        when :matches
          record_scope.where("#{column.attribute_for_condition} LIKE ?", "%#{normalize(value)}%")
        when :does_not_match
          record_scope.where("#{column.attribute_for_condition} NOT LIKE ?", "%#{normalize(value)}%")
        when :is
          val = value.is_a?(Array) ? value : normalize(value)
          record_scope.where(column.attribute_for_condition => val)
        when :isnt
          val = value.is_a?(Array) ? value : normalize(value)
          record_scope.where.not(column.attribute_for_condition => val)
        else
          # Ignore unknown operators
          record_scope
        end
      end
    end

    def operators
      operators = Mensa::Filter.OPERATORS.dup
      if config[:operators].present?
        operators = operators.select { |op| config[:operators].include?(op[0]) }
      else
        operators.delete_if { |op| op[0] == :is_current } unless Current.method_defined?(column.name, false)
        operators.delete_if { |op| op[0] == :matches } if collection.present?
        operators.delete_if { |op| op[0] == :does_not_match } if collection.present?
        operators.delete_if { |op| op[0] == :matches } if column.type == :integer
        operators.delete_if { |op| op[0] == :does_not_match } if column.type == :integer
      end
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
