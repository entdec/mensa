# frozen_string_literal: true

module Mensa
  class Filter
    include ConfigReaders

    defined_by Mensa::Config::FilterDsl

    attr_reader :column, :table

    config_reader :operator, cast: :to_sym
    config_reader :value
    config_reader :scope, call: false
    config_reader :multiple
    config_reader :having?

    # Types that ILIKE works on, nil is an attribute without a type
    TEXT_TYPES = [:string, :text, :citext, nil].freeze
    # Types with a meaningful order, for gt, gteq, lt and lteq
    RANGE_TYPES = %i[integer bigint float decimal money date datetime timestamp timestamptz time interval].freeze
    # Types where an exact match on a value is of little use
    POINT_IN_TIME_TYPES = %i[date datetime timestamp timestamptz].freeze
    # Types that can't be compared with a value the user types
    STRUCTURED_TYPES = %i[json jsonb].freeze

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
          [:is_duplicate, I18n.t("mensa.operators.is_duplicate"), false],
          [:is_current, I18n.t("mensa.operators.is_current"), false],
          [:is_empty, I18n.t("mensa.operators.is_empty"), false],
          [:isnt_empty, I18n.t("mensa.operators.isnt_empty"), false]
        ].freeze
      end
    end

    def initialize(column:, config:, table:)
      @column = column
      @config = self.class.definition.merge(config || {})
      @table = table
      validate_operators!
    end

    def multiple?
      !!multiple
    end

    def collection?
      config&.key?(:collection)
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
        record_scope.instance_exec(*scope_arguments, &scope)
      else
        return apply_duplicate_filter(record_scope) if operator == :is_duplicate

        # Nothing selected in a multi-select means no filter
        return record_scope if value.is_a?(Array) && value.compact_blank.empty?
        # A value the database can't compare with the column, e.g. "abc" for
        # a number, matches nothing instead of raising
        return record_scope.none if operator_with_value? && invalid_value?

        query, hash = query_and_hash_for_operator
        record_scope = (having? ? record_scope.having(query, hash) : record_scope.where(query, hash)) if query.present?
        record_scope
      end
    end

    def operators
      operators = Mensa::Filter.OPERATORS.dup
      if config[:operators].present?
        operators = operators.select { |op| config[:operators].include?(op[0]) }
      else
        operators.delete_if { |op| op[0] == :is_current } unless Current.method_defined?(column.name, false)
        type = column.type
        operators.delete_if { |op| [:matches, :does_not_match].include?(op[0]) } if collection.present?
        # Only these operators work for the column's type in SQL, the others
        # raise, e.g. LIKE on a boolean
        operators.delete_if { |op| [:matches, :does_not_match].include?(op[0]) } unless TEXT_TYPES.include?(type)
        operators.delete_if { |op| [:gt, :lt, :gteq, :lteq].include?(op[0]) } unless RANGE_TYPES.include?(type)
        operators.delete_if { |op| [:is, :isnt].include?(op[0]) } if POINT_IN_TIME_TYPES.include?(type) || STRUCTURED_TYPES.include?(type)
        # json has no equality, so duplicates can't be grouped
        operators.delete_if { |op| op[0] == :is_duplicate } if type == :json
      end
      operators
    end

    # Used in the where clause
    def query_and_hash_for_operator
      col = "(#{column.attribute_for_condition})"
      hash = {value: normalize(value)}
      hash[:value] = hash[:value].compact_blank if hash[:value].is_a?(Array)

      query = case operator
      when :is_empty
        (column.type == :string) ? "#{col} IS NULL OR #{col} = ''" : "#{col} IS NULL"
      when :isnt_empty
        (column.type == :string) ? "#{col} IS NOT NULL AND #{col} != ''" : "#{col} IS NOT NULL"
      when :is_current
        hash[:value] = Current.public_send(column.name)
        "#{col} = :value"
      when :matches
        hash[:value] = contains_pattern(hash[:value])
        "#{text_col(col)} ILIKE :value"
      when :does_not_match
        # Rows without a value don't contain it either
        hash[:value] = contains_pattern(hash[:value])
        "(#{col} IS NULL OR #{text_col(col)} NOT ILIKE :value)"
      when :is
        hash[:value].is_a?(Array) ? "#{col} IN (:value)" : "#{col} = :value"
      when :isnt
        hash[:value].is_a?(Array) ? "#{col} NOT IN (:value)" : "#{col} != :value"
      when :gt
        "#{col} > :value"
      when :lt
        "#{col} < :value"
      when :gteq
        "#{col} >= :value"
      when :lteq
        "#{col} <= :value"
      else
        raise ArgumentError, "Unknown filter operator #{operator.inspect} for column :#{column.name}"
      end
      [query, hash]
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
      when :time
        "time"
      else
        "text"
      end
    end

    private

    def validate_operators!
      valid_keys = Mensa::Filter.OPERATORS.map(&:first)

      op = @config[:operator]
      if op.present? && valid_keys.exclude?(op.to_sym)
        raise ArgumentError, "Unknown filter operator #{op.inspect} configured for column :#{column.name}. " \
          "Valid operators are: #{valid_keys.join(", ")}"
      end

      allowed_ops = Array(@config[:operators])
      invalid = allowed_ops.map(&:to_sym) - valid_keys
      if invalid.any?
        raise ArgumentError, "Unknown filter operator(s) #{invalid.map(&:inspect).join(", ")} configured for column :#{column.name}. " \
          "Valid operators are: #{valid_keys.join(", ")}"
      end
    end

    # Arguments for a custom filter scope: the value and the operator. Lambdas
    # only get as many as they declare, so `->(value) { ... }` keeps working
    # next to `->(value, operator) { ... }`. Plain procs ignore extra arguments.
    def scope_arguments
      args = [normalize(value), operator]
      return args unless scope.lambda?
      return args if scope.parameters.any? { |type, _| type == :rest }

      args.first(scope.parameters.count { |type, _| type == :req || type == :opt })
    end

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

    def apply_duplicate_filter(record_scope)
      column_sql = column.attribute_for_condition.to_s
      base_scope = record_scope.except(:select, :order, :limit, :offset)
      return apply_duplicate_having_filter(record_scope, base_scope, column_sql) if having?

      duplicate_values_scope = base_scope
        .where("#{column_sql} IS NOT NULL")
        .group(column_sql)
        .having("COUNT(*) > 1")
        .select(Arel.sql(column_sql))

      record_scope
        .where("#{column_sql} IS NOT NULL")
        .where("#{column_sql} IN (#{duplicate_values_scope.to_sql})")
    end

    UUID_FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/

    # Whether a value can't be read as the column's type. Values are sent to
    # the database as they are, this only catches the ones it would reject.
    def invalid_value?
      Array(value).compact_blank.any? { |entry| !valid_for_type?(entry) }
    end

    def valid_for_type?(entry)
      return true unless entry.is_a?(String)

      case column.type
      when :integer, :bigint then entry.strip.match?(/\A[+-]?\d+\z/)
      when :decimal, :float then entry.strip.match?(/\A[+-]?(\d+\.?\d*|\.\d+)\z/)
      when :date then Date.parse(entry).present?
      when :datetime, :timestamp, :timestamptz then Time.zone.parse(entry).present?
      when :time then entry.strip.match?(/\A\d{1,2}:\d{2}(:\d{2}(\.\d+)?)?\z/)
      when :uuid then entry.strip.match?(UUID_FORMAT)
      else true
      end
    rescue ArgumentError, RangeError
      false
    end

    # Aggregates are only known per group, so the duplicate values come from
    # a subquery of the grouped rows and are compared in the HAVING
    def apply_duplicate_having_filter(record_scope, base_scope, column_sql)
      duplicate_values_scope = base_scope.model.unscoped
        .from(base_scope.select(Arel.sql("#{column_sql} AS mensa_duplicate_value")), :mensa_values)
        .where("mensa_values.mensa_duplicate_value IS NOT NULL")
        .group("mensa_values.mensa_duplicate_value")
        .having("COUNT(*) > 1")
        .select("mensa_values.mensa_duplicate_value")

      record_scope.having("#{column_sql} IN (#{duplicate_values_scope.to_sql})")
    end

    # A case-insensitive "contains" pattern, with %, _ and \ in the value
    # matched literally. A blank value is compared as it is, like `is` does,
    # so it doesn't turn into '%%' and match everything.
    def contains_pattern(value)
      return value if value.to_s.empty?

      "%#{ActiveRecord::Base.sanitize_sql_like(value.to_s)}%"
    end

    # An attribute without a type may not be text in SQL (e.g. a count), cast
    # it like search does. Typed columns are compared as they are, so an
    # explicit `matches` on e.g. a boolean still fails (and the verifier
    # reports it).
    def text_col(col)
      column.type.nil? ? "CAST(#{col} AS text)" : col
    end

    # Unused at the moment
    def normalize(query)
      query
    end
  end
end
