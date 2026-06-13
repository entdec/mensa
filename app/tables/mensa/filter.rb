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
          [:gt, I18n.t("mensa.operators.gt"), true],
          [:gteq, I18n.t("mensa.operators.gteq"), true],
          [:lt, I18n.t("mensa.operators.lt"), true],
          [:lteq, I18n.t("mensa.operators.lteq"), true],
          [:is_current, I18n.t("mensa.operators.is_current"), false],
          [:is_empty, I18n.t("mensa.operators.is_empty"), false]
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
      parts << formatted_value if formatted_value.present? && operator_with_value?
      parts.join(" ")
    end

    def formatted_value
      options = collection_options

      if value.is_a?(Array)
        value.map { |entry| label_for_value(entry, options) }.join(", ")
      else
        label_for_value(value, options)
      end
    end

    def filter_scope(record_scope)
      if scope
        record_scope.instance_exec(normalize(value), &scope)
      else
        case operator
        when :is_empty
          if column.type == :string
            record_scope.where("#{column.attribute_for_condition} IS NULL OR #{column.attribute_for_condition} = ''")
          else
            record_scope.where("#{column.attribute_for_condition} IS NULL")
          end
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
        when :gt
          record_scope.where(column.table.model.arel_table[column.attribute_for_condition].gt(normalize(value)))
        when :lt
          record_scope.where(column.table.model.arel_table[column.attribute_for_condition].lt(normalize(value)))
        when :gteq
          record_scope.where(column.table.model.arel_table[column.attribute_for_condition].gteq(normalize(value)))
        when :lteq
          record_scope.where(column.table.model.arel_table[column.attribute_for_condition].lteq(normalize(value)))
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
        operators.delete_if { |op| [:matches, :does_not_match].include?(op[0]) } if collection.present?
        operators.delete_if { |op| [:matches, :does_not_match].include?(op[0]) } if column.type == :integer || column.type == :date || column.type == :datetime
        operators.delete_if { |op| [:is, :isnt].include?(op[0]) } if column.type == :date || column.type == :datetime
        operators.delete_if { |op| [:gt, :lt, :gteq, :lteq].include?(op[0]) } if column.type == :string || column.type.blank?
      end
      operators
    end

    def operator_label
      Mensa::Filter.OPERATORS.find { |op| op[0] == operator }[1]
    end

    def operator_with_value?
      Mensa::Filter.OPERATORS.find { |op| op[0] == operator }[2]
    end

    def input_type
      case column.type
      when :integer
        "number"
      when :date
        "date"
      when :datetime
        "datetime-local"
      else
        "text"
      end
    end

    private

    def label_for_value(selected_value, options)
      option = options.find { |_label, value| value.to_s == selected_value.to_s }
      option ? option.first : selected_value
    end

    def collection_options
      collection = column.filter&.collection
      return [] if collection.blank?

      collection.map do |item|
        item.is_a?(Array) ? [item.first.to_s, item.last.to_s] : [item.to_s, item.to_s]
      end
    end

    # Unused at the moment
    def normalize(query)
      query # .to_s.gsub(/\s(?![&!|])/, '\\\\ ')
    end
  end
end
