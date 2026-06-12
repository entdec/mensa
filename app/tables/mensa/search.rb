# frozen_string_literal: true

module Mensa
  module Search
    extend ActiveSupport::Concern

    private

    def search(record_scope, query)
      return record_scope if query.blank?
      return record_scope unless record_scope.is_a?(ActiveRecord::Relation)

      searchable_attributes = columns.filter_map(&:attribute_for_condition).uniq
      return record_scope if searchable_attributes.empty?

      @search_order_clause = nil

      fuzzy_search?(record_scope) ? fuzzy_search(record_scope, searchable_attributes, query.to_s) : basic_search(record_scope, searchable_attributes, query.to_s)
    end

    def basic_search(record_scope, searchable_attributes, query)
      sanitized_query = ActiveRecord::Base.sanitize_sql_like(query)
      conditions = searchable_attributes.map do |attribute|
        "CAST((#{attribute}) AS text) ILIKE :term"
      end.join(" OR ")

      record_scope.where(conditions, term: "%#{sanitized_query}%")
    end

    def fuzzy_search(record_scope, searchable_attributes, query)
      sanitized_query = ActiveRecord::Base.sanitize_sql_like(query)
      compare_quoted = record_scope.model.connection.quote(query)
      text_expression = searchable_text_expression(searchable_attributes)
      score_sql = "similarity(#{text_expression}, #{compare_quoted})"

      @search_order_clause = "#{score_sql} DESC"

      record_scope
        .select(Arel.sql("#{score_sql} AS mensa_search_score"))
        .where("#{text_expression} % :query OR #{text_expression} ILIKE :term", query: query, term: "%#{sanitized_query}%")
        .order(Arel.sql(@search_order_clause))
    end

    def searchable_text_expression(searchable_attributes)
      fields = searchable_attributes.map do |attribute|
        "COALESCE(CAST((#{attribute}) AS text), '')"
      end.join(", ")

      "CONCAT_WS(' ', #{fields})"
    end

    def search_order_clause
      @search_order_clause
    end

    def fuzzy_search?(record_scope)
      Mensa.config.search == :fuzzy && pg_trgm_enabled?(record_scope)
    end

    def pg_trgm_enabled?(record_scope)
      connection = record_scope.model.connection
      return false unless connection.adapter_name.to_s.downcase.include?("postgres")
      return connection.extension_enabled?("pg_trgm") if connection.respond_to?(:extension_enabled?)

      connection.select_value("SELECT 1 FROM pg_extension WHERE extname = 'pg_trgm' LIMIT 1").present?
    rescue
      false
    end
  end
end
