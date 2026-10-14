# frozen_string_literal: true

require "csv"
require "json"
require "stringio"
require "mensa/verifier/result"

module Mensa
  # Checks that everything a table configures works against the real database:
  # its scope, every column's SQL, sorting, rendering, filters, search, the CSV
  # export, grouping/aggregates and its views. It also warns about N+1 queries
  # and slow queries.
  #
  #   result = Mensa::Verifier.new(UsersTable, user: User.first).call
  #   result.success? # => true
  #   puts result     # per-check report
  #
  # Checks go through the same code paths as requests do (filtered_scope,
  # ordered_scope, Mensa::Cell, the components, Mensa::ExportJob, ...).
  # Everything runs in a read-only transaction that is rolled back, and every
  # check in its own savepoint so one failing query doesn't stop the others.
  #
  # Tables often depend on request context, give it with user:, account: and
  # context: (all set on Current while verifying), params: (the table's
  # params) or a block, which is called with the verifier before the checks.
  # Mensa.config.verifier_context supplies defaults for these, or a list of
  # them to verify a table in several contexts (see Verifier.verify).
  class Verifier
    # Records sampled from the first and the last page
    SAMPLE_SIZE = 5
    LAST_PAGE_SAMPLE = 2

    # Statements that aren't the table's queries
    IGNORED_QUERY = /\A\s*(SAVEPOINT|RELEASE|ROLLBACK|BEGIN|COMMIT|SET|SHOW)\b/i

    class Skip < StandardError; end

    # A problem the verifier found itself, reported without the class name
    class Failure < StandardError; end

    # A record to render, and why it was sampled
    Sample = Struct.new(:row, :reason) do
      def description
        id = row.record.id if row.record.respond_to?(:id)
        [("record #{id}" if id), "(#{reason})"].compact.join(" ")
      end
    end

    attr_reader :table_class, :user, :account, :context, :params, :label, :result

    class << self
      # Accepts a table class, its name (e.g. "UsersTable") or Mensa's table
      # name (e.g. "users", "admin_users").
      def resolve_table_class(table)
        return table if table.is_a?(Module)

        name = table.to_s
        (name.safe_constantize if name.match?(/\A[A-Z]/)) || Mensa.class_for_name(name.underscore.delete_suffix("_table"))
      end

      # The classes and modules defined by the files under +root+ (the app's
      # app/tables), including any that aren't Mensa tables, which are
      # reported as skipped.
      def table_classes(root = Rails.root.join("app/tables"))
        loader = Rails.autoloaders.main

        Dir[File.join(root.to_s, "**/*.rb")].filter_map { |path|
          loader.cpath_expected_at(path)&.safe_constantize
        }.uniq.sort_by(&:name)
      end

      # Verifies +table+ in every context Mensa.config.verifier_context
      # returns for it (a hash, or an array of them), with +options+ on top.
      # Returns one result per context.
      def verify(table, **options, &setup)
        table_class = resolve_table_class(table)
        options = options.compact

        contexts_for(table_class).map do |defaults|
          new(table_class, **options, defaults: defaults, &setup).call
        end
      end

      # The option hashes Mensa.config.verifier_context gives for a table
      def contexts_for(table_class)
        return [{}] unless table_class.is_a?(Class) && table_class < Mensa::Base

        contexts = Mensa.config.verifier_context&.call(table_class)
        contexts = [contexts] unless contexts.is_a?(Array)
        contexts.map { |context| context.is_a?(Hash) ? context.symbolize_keys : {} }.presence || [{}]
      end

      # Verifies the tables (all under app/tables when none are given), prints
      # their reports to +io+ and returns true when all of them passed.
      # Context comes from USER_ID, ACCOUNT_ID and PARAMS (JSON) in +env+, and
      # STRICT=1 makes warnings fail, used by the mensa:verify rake tasks.
      # The reports list failures and warnings, +verbose+ (or VERBOSE=1) lists
      # every check and the classes skipped as they aren't Mensa tables.
      def run(tables = nil, env: ENV, io: $stdout, verbose: false)
        classes = tables.present? ? Array(tables).map { |table| resolve_table_class(table) } : table_classes
        options = options_from_env(env)
        verbose ||= %w[1 true yes].include?(env["VERBOSE"].to_s.downcase)

        results = classes.flat_map do |klass|
          verify(klass, **options).each do |result|
            io.puts(result.to_s(verbose: verbose), "") if verbose || result.mensa_table?
          end
        end

        by_table = results.select(&:mensa_table?).group_by(&:table_class)
        others = results.reject(&:mensa_table?)
        if by_table.size > 1 || (verbose && results.size > 1)
          passed = by_table.count { |_table, table_results| table_results.all?(&:success?) }
          io.puts ["#{passed}/#{by_table.size} tables passed", ("#{others.size} skipped, not a Mensa::Base subclass" if verbose && others.any?)].compact.join(", ")
        end
        results.all?(&:success?)
      end

      def options_from_env(env)
        options = {}
        options[:user] = "User".constantize.find(env["USER_ID"]) if env["USER_ID"].present?
        options[:account] = "Account".constantize.find(env["ACCOUNT_ID"]) if env["ACCOUNT_ID"].present?
        options[:params] = JSON.parse(env["PARAMS"]) if env["PARAMS"].present?
        options[:strict] = true if %w[1 true yes].include?(env["STRICT"].to_s.downcase)
        options
      end
    end

    # +strict+ makes warnings fail, +slow_query+ is the duration in seconds
    # from which a query is reported (Mensa.config.verifier_slow_query).
    # +defaults+ replaces the first context of Mensa.config.verifier_context.
    def initialize(table, user: nil, account: nil, context: {}, params: nil, label: nil, strict: false, slow_query: nil, view_context: nil, defaults: nil, &setup)
      @table_class = self.class.resolve_table_class(table)
      defaults ||= self.class.contexts_for(@table_class).first
      @user = user || defaults[:user]
      @account = account || defaults[:account]
      @context = (defaults[:context] || {}).merge(context || {})
      @params = params || defaults[:params] || {}
      @label = label || defaults[:label] || context_label
      @slow_query = slow_query || defaults[:slow_query] || Mensa.config.verifier_slow_query
      @view_context = view_context
      @setup = setup
      @result = Result.new(@table_class, strict: strict || defaults[:strict], label: @label)
    end

    def call
      return result if @called

      @called = true
      unless result.mensa_table?
        result.checks << Check.new(section: :loads, name: "Mensa table", status: :skipped, message: "#{table_class} does not descend from Mensa::Base")
        return result
      end

      @queries = []
      @reported_n_plus_one = Set.new
      @per_record_renders = 0
      thread = Thread.current
      ActiveSupport::Notifications.subscribed(->(event) { record_query(event) if Thread.current == thread }, "sql.active_record") do
        read_only_transaction do
          with_current_attributes do
            @setup&.call(self)
            run_checks
          end
        end
      end
      result
    end

    # Mensa's name for the table, as used in its routes and saved views
    def table_name
      @table_name ||= table_class.name.underscore.delete_suffix("_table").tr("/", "_")
    end

    # Builds the table like a request would, with the request config on top
    def build_table(config = {})
      table = table_class.new({params: params}.merge(config))
      table.name = table_name
      table.request = request
      table.original_view_context = view_context
      table
    end

    def request
      @request ||= ActionDispatch::Request.new(Rack::MockRequest.env_for("http://#{default_host}/"))
    end

    # A view context of the app's base controller, so html render blocks have
    # the app's helpers and url helpers.
    def view_context
      @view_context ||= Mensa.offline_view_context(request)
    end

    private

    def default_host
      Rails.application.routes.default_url_options[:host] || "localhost"
    end

    # Names the context in the report, e.g. "user: User#1, params: {...}"
    def context_label
      values = context.symbolize_keys.merge({user: user, account: account}.compact)
      parts = values.map { |key, value| "#{key}: #{value.is_a?(ActiveRecord::Base) ? "#{value.class.name}##{value.id}" : value.inspect}" }
      parts << "params: #{params.to_json}" if params.present?
      parts.join(", ").presence
    end

    def run_checks
      @table = check(:loads, nil, "build table") { build_table }
      unless @table
        result.checks << Check.new(section: :loads, name: "remaining checks", status: :skipped, message: "the table could not be built")
        return
      end

      # A table of its own, a relation can't be counted after its to_sql
      check(:loads, nil, "build SQL") { |c| c.sql = build_table.selected_scope.to_sql }
      @rows = check(:loads, nil, "load first page") { @table.rows }
      verify_last_page
      verify_defaults
      @samples = check(:loads, nil, "sample records") { |c| load_samples.tap { |samples| c.name = sample_name(samples) } } if @rows

      verify_columns
      verify_filters
      verify_search
      verify_rendering
      verify_n_plus_one
      verify_layout
      verify_combined
      verify_exports
      verify_grouping
      verify_views
    end

    # Checks

    # Runs the block as one check in its own savepoint and records the
    # outcome, then any warnings found while running it. Returns the block's
    # value, nil when the check didn't pass. Quiet checks are only reported
    # when they fail.
    def check(section, subject, name, quiet: false)
      c = Check.new(section: section, subject: subject, name: name)
      outer_warnings = @warnings
      @warnings = []
      start = @queries.size
      value = nil
      savepoint { value = yield(c) }
      c.status = :passed
      value
    rescue Skip => e
      c.status = :skipped
      c.message = e.message
      nil
    rescue StandardError, ScriptError => e
      c.status = :failed
      c.error = e
      c.message = e.is_a?(Failure) ? e.message : "#{e.class}: #{e.message}#{error_hint(e)}"
      c.sql = e.sql if e.respond_to?(:sql) && e.sql.present?
      nil
    ensure
      result.checks << c unless quiet && c.passed?
      warn_slow_queries(section, subject, @queries[start..]) if c.passed?
      result.checks.concat(@warnings)
      @warnings = outer_warnings
    end

    def skip!(reason)
      raise Skip, reason
    end

    def warn!(section, subject, name, message, sql = nil)
      warning = Check.new(section: section, subject: subject, name: name, status: :warning, message: message, sql: sql)
      @warnings ? @warnings << warning : result.checks << warning
    end

    def savepoint
      ActiveRecord::Base.transaction(requires_new: true) do
        yield
        raise ActiveRecord::Rollback
      end
    end

    # The block's value, or nil when it raises
    def attempt
      value = nil
      savepoint { value = yield }
      value
    rescue
      nil
    end

    # Fixes for errors that have a common cause
    def error_hint(error)
      error = error.cause if error.is_a?(ActionView::Template::Error) && error.cause
      return unless error.is_a?(ActiveModel::MissingAttributeError)

      attribute = error.message[/missing attribute '?(\w+)'?/, 1]
      "\nFix: Mensa only selects the table's columns, add `internal :#{attribute}` to select #{attribute} too." if attribute
    end

    # Queries

    def record_query(event)
      payload = event.payload
      return if payload[:cached] || %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:sql].to_s.match?(IGNORED_QUERY)

      @queries << {sql: payload[:sql], duration: event.duration / 1000.0}
    end

    def warn_slow_queries(section, subject, queries)
      slow = queries.select { |query| query[:duration] >= @slow_query }
      return if slow.empty?

      slowest = slow.max_by { |query| query[:duration] }
      warn!(section, subject, "slow query",
        "took #{format("%.2f", slowest[:duration])}s (reported from #{@slow_query}s#{", #{slow.size} slow queries" if slow.size > 1}).\n" \
        "Fix: check its plan with EXPLAIN ANALYZE, e.g. for a missing index.", slowest[:sql])
    end

    # Records

    # Samples to render: records from the first and the last page, and a
    # record with an empty value for each column, where null values often
    # break render blocks.
    def load_samples
      samples = @rows.first(SAMPLE_SIZE).map { |row| Sample.new(row, "first page") }

      pages = @table.pagy_details.pages
      build_table_on_page(pages).rows.last(LAST_PAGE_SAMPLE).each { |row| samples << Sample.new(row, "last page") } if pages > 1

      @table.columns.reject(&:internal?).select(&:filter?).each do |column|
        next if column.attribute_for_condition.blank?
        next if samples.any? { |sample| attempt { sample.row.value(column).nil? } }

        sample = attempt do
          table = build_table(filters: {column.name => {operator: :is_empty}})
          record = table.selected_scope.limit(1).first
          Sample.new(Mensa::Row.new(table, record), "#{column.name} empty") if record
        end
        samples << sample if sample
      end

      samples.uniq { |sample| sample.row.record.respond_to?(:id) ? sample.row.record.id : sample.row.record.object_id }
    end

    def sample_name(samples)
      "sample #{samples.size} #{"record".pluralize(samples.size)}#{" (#{samples.map(&:reason).uniq.join(", ")})" if samples.any?}"
    end

    def build_table_on_page(page)
      table = build_table
      table.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("http://#{default_host}/?page=#{page}"))
      table
    end

    # Record-level checks need sampled records
    def sample_rows!
      skip!("records could not be loaded") if @samples.nil?
      skip!("no records") if @samples.empty?

      @samples
    end

    # Renders every sample in its own savepoint. Fails naming the records that
    # failed, and warns about queries that run for each record (N+1).
    def render_samples(section, subject, what)
      errors = []
      queries_per_record = sample_rows!.map do |sample|
        start = @queries.size
        begin
          savepoint { yield sample.row }
        rescue StandardError, ScriptError => e
          errors << "#{sample.description}: #{e.class}: #{e.message}#{error_hint(e)}"
        end
        @queries[start..].map { |query| query[:sql] }.uniq
      end

      warn_n_plus_one(section, subject, what, queries_per_record)
      raise Failure, errors.join("\n") if errors.any?
    end

    def warn_n_plus_one(section, subject, what, queries_per_record)
      return if queries_per_record.size < 2

      @per_record_renders += 1

      queries_per_record.flatten.tally.each do |sql, records|
        next if records < 2
        next unless @reported_n_plus_one.add?([subject, sql])

        warn!(section, subject, "N+1 query in #{what}",
          "runs this query for each record (#{records} of #{queries_per_record.size} sampled records).#{n_plus_one_hint(sql)}", sql)
      end
    end

    # How to avoid a query per record, from the association it loads
    def n_plus_one_hint(sql)
      model = @table.model
      table = sql[/\bFROM\s+"?(\w+)"?/i, 1]
      reflection = model.reflect_on_all_associations.find do |association|
        !association.polymorphic? && association.klass.table_name == table
      rescue NameError
        false
      end
      return "\nFix: select the value in SQL with `attribute`, or preload what the block uses in `scope`." unless reflection

      preload = "`scope { #{model.name}.includes(:#{reflection.name}) }`"
      hints = if reflection.belongs_to?
        foreign_key = reflection.foreign_key.to_s
        selected = @table.columns.any? { |column| column.name.to_s == foreign_key }
        [
          "preload it with #{preload}#{" and add `internal :#{foreign_key}`, Mensa only selects the table's columns and the preload needs the foreign key" unless selected}",
          "or select the value in SQL with `attribute \"#{table}.<column>\"` and `left_outer_joins(:#{reflection.name})` in `scope`"
        ]
      else
        hints = ["preload it with #{preload}"]
        if sql.match?(/\bCOUNT\(/i) && reflection.collection?
          hints << "and use `.size` instead of `.count`, which always queries"
          unless reflection.through_reflection?
            hints << "or count in SQL with `attribute \"(SELECT COUNT(*) FROM #{table} WHERE #{table}.#{reflection.foreign_key} = #{model.table_name}.#{model.primary_key})\"` and `type :integer`"
          end
        end
        hints
      end
      "\nFix: #{hints.join(",\n     ")}."
    end

    # Loads

    def verify_last_page
      check(:loads, nil, "load last page") do
        skip!("records could not be loaded") if @rows.nil?

        pages = @table.pagy_details.pages
        skip!("only one page") if pages < 2

        build_table_on_page(pages).rows
      end
    end

    # Defaults on the table itself that Mensa would silently ignore
    def verify_defaults
      config = @table.config.slice(:order, :column_order).compact_blank
      return if config.empty?

      check(:loads, nil, "configured #{config.keys.join(", ")}") do
        problems = config_problems(config)
        raise Failure, problems.join("\n") if problems.any?
      end
    end

    # Columns

    def verify_columns
      @table.columns.each do |column|
        verify_column_select(column)
        verify_column_sort(column) if column.sortable? && !column.internal?
        verify_column_render(column) unless column.internal?
      end
    end

    def verify_column_select(column)
      check(:columns, column.name, "select") do |c|
        skip!("no SQL attribute, the value comes from #{column.method ? "method :#{column.method}" : "the record"}") if column.attribute.blank?

        # What Mensa selects besides the column: the id and internal columns,
        # which preloads in the scope need
        table = build_table
        selects = (table.send(:id_column?) ? [:id] : []) + table.columns.select(&:internal?).filter_map(&:attribute)
        relation = table.filtered_scope.select(*selects, Arel.sql(column.attribute)).limit(1)
        c.sql = relation.to_sql
        result = table.model.connection.select_all(relation)
        warn_untyped_attribute(column, result.column_types[column.name.to_s]&.type)
      end
    end

    # The SQL type of an `attribute` decides which filter operators and values
    # fit it. Without `type`, Mensa treats it as text: it offers LIKE and
    # compares with text, which fails for e.g. a boolean expression.
    def warn_untyped_attribute(column, sql_type)
      return if column.config[:attribute].blank? || column.config[:type].present?
      return if sql_type.nil? || Mensa::Filter::TEXT_TYPES.include?(sql_type)

      type = {timestamptz: :datetime, timestamp: :datetime}.fetch(sql_type, sql_type)
      warn!(:columns, column.name, "untyped attribute",
        "its SQL is #{sql_type}, but without `type` Mensa treats it as text: filters offer text operators and compare with text.\n" \
        "Fix: add `type :#{type}` to the column.")
    end

    def verify_column_sort(column)
      check(:columns, column.name, "sort asc/desc") do
        %i[asc desc].each { |direction| build_table(order: {column.name => direction}).ordered_scope.limit(1).load }
      end
    end

    def verify_column_render(column)
      visible = check(:columns, column.name, "visible", quiet: true) { column.visible? }
      return if visible.nil?

      formats = @table.exportable? ? %i[html csv] : %i[html]
      formats.each do |format|
        check(:columns, column.name, "render #{format}") do
          skip!("not visible") unless visible

          render_samples(:columns, column.name, "render #{format}") { |row| Mensa::Cell.new(row: row, column: column).render(format) }
        end
      end
    end

    # Filters

    def verify_filters
      @table.columns.select(&:filter?).each do |column|
        operators = check(:filters, column.name, "operators", quiet: true) { column.filter.operators }
        next unless operators

        values = check(:filters, column.name, "collection", quiet: true) { filter_values(column) }
        next unless values

        if operators.any? { |operator, *| operator == :is_current }
          reason = check(:filters, column.name, "is_current", quiet: true) { missing_current_reason(column) }
          if reason
            operators = operators.reject { |operator, *| operator == :is_current }
            check(:filters, column.name, "is_current") { skip!(reason) }
          end
        end

        invalid = invalid_value(column)
        check(:filters, column.name, filter_check_name(column, operators, values, invalid)) do |c|
          errors = operators.filter_map { |operator, _label, with_value| filter_error(column, operator, filter_value(column, operator, with_value, values)) }
          if invalid
            errors += operators.select { |_operator, _label, with_value| with_value }.filter_map { |operator, *| filter_error(column, operator, invalid) }
          end
          next if errors.empty?

          c.sql = errors.first[:sql]
          raise Failure, errors.map { |error| error[:message] }.join("\n")
        end
      end
    end

    def filter_check_name(column, operators, values, invalid)
      name = "#{operators.map(&:first).join(", ")} (#{(column.filter.multiple? ? values : values.first).inspect})"
      invalid ? "#{name}, invalid input (#{invalid.inspect})" : name
    end

    # Applies the filter with one operator in its own savepoint, returns
    # {message:, sql:} when it fails
    def filter_error(column, operator, value)
      relation = nil
      savepoint do
        table = build_table(filters: {column.name => {operator: operator, value: value}.compact})
        relation = table.filtered_scope.limit(SAMPLE_SIZE)
        relation.load
        # The filter pill's text
        table.active_filters.each(&:to_s)
      end
      nil
    rescue StandardError, ScriptError => e
      sql = e.sql if e.respond_to?(:sql)
      sql ||= relation.to_sql if relation
      {message: "#{operator}#{" #{value.inspect}" if value}: #{e.class}: #{e.message}", sql: sql}
    end

    # is_current compares with Current.<column>, which needs context such as
    # a user. Returns why it can't be checked, nil when it can.
    def missing_current_reason(column)
      value = begin
        ::Current.public_send(column.name)
      rescue NoMethodError => e
        return "Current.#{column.name} raised #{e.message}, give the verifier a context (user:, context:)"
      end
      "Current.#{column.name} is nil, give the verifier a context (user:, context:)" if value.nil?
    end

    # The first values of the filter's collection, or a synthetic value
    def filter_values(column)
      collection = Array(column.filter.collection).filter_map { |item| item.is_a?(Array) ? item.last : item }
      values = collection.compact_blank.first(2).map(&:to_s)
      values.presence || [synthetic_value(column)]
    end

    def filter_value(column, operator, with_value, values)
      return unless with_value
      return values if column.filter.multiple? && %i[is isnt].include?(operator)

      values.first
    end

    # A value as the filter popover would send it for the column's type
    def synthetic_value(column)
      case column.type
      when :integer, :bigint, :decimal, :float then "1"
      when :date then Date.current.iso8601
      when :datetime, :timestamp, :timestamptz then Time.current.strftime("%Y-%m-%dT%H:%M")
      when :time then "12:00"
      when :boolean then "true"
      when :uuid then SecureRandom.uuid
      else "a"
      end
    end

    # A value a user could type that the column's type can't hold
    def invalid_value(column)
      case column.type
      when :integer, :bigint, :decimal, :float then "not a number"
      when :date, :datetime, :timestamp, :timestamptz then "not a date"
      when :time then "not a time"
      when :uuid then "not a uuid"
      end
    end

    # Search

    # Both search modes, the app may switch between them
    def verify_search
      term = search_term

      %i[basic fuzzy].each do |mode|
        check(:search, nil, "#{mode} #{term.inspect}") do |c|
          with_search_mode(mode) do
            table = build_table(query: term)
            skip!("needs the pg_trgm extension") if mode == :fuzzy && !table.send(:fuzzy_search?, table.scope)

            # Search uses every column, so load what requests load
            relation = table.selected_scope.limit(SAMPLE_SIZE)
            c.sql = relation.to_sql
            relation.load
          end
        end
      end
    end

    def with_search_mode(mode)
      previous = Mensa.config.search
      Mensa.config.search = mode
      yield
    ensure
      Mensa.config.search = previous
    end

    # A word from the first string value in the records, so it finds something
    def search_term
      @search_term ||= begin
        words = (@rows || []).first(SAMPLE_SIZE).lazy.flat_map { |row|
          @table.display_columns.map { |column| row.value(column) }
        }.select { |value| value.is_a?(String) && value.split.first.present? }
        words.first&.split&.first&.first(20) || "a"
      rescue
        "a"
      end
    end

    # Rendering, like the app's views and Mensa's controllers do

    def verify_rendering
      check(:render, nil, "table component") { view_context.table(table_name, params: params) }
      check(:render, nil, "rows and filter pills") { render_page(build_table, view: @table.default_system_view) }

      check(:render, nil, "row link") { render_samples(:render, nil, "row link", &:link) } if @table.link

      return unless @table.actions?

      @table.actions.each do |action|
        check(:render, :actions, action.name.to_s) do
          render_samples(:render, :actions, action.name.to_s) do |row|
            view_context.render(Mensa::RowAction::Component.new(table: @table, row: row, action: action))
          end
        end
      end
    end

    # Confirms no N+1 query was found, after everything rendered per record
    # (column renders, the row link, row actions). Found ones are warnings.
    def verify_n_plus_one
      return if @reported_n_plus_one.any?

      check(:render, nil, "N+1 queries") do |c|
        skip!("records could not be loaded") if @samples.nil?
        skip!("no records") if @samples.empty?
        skip!("needs at least 2 sampled records, found 1") if @samples.one?
        skip!("nothing is rendered per record") if @per_record_renders.zero?

        c.name = "N+1 queries: none in #{@per_record_renders} #{"render".pluralize(@per_record_renders)} of #{@samples.size} sampled records"
      end
    end

    # What Mensa::TablesController#show renders into the table's turbo frame
    def render_page(table, view: nil)
      table.table_view = view
      view_context.render(Mensa::FilterPillList::Component.new(table: table))
      view_context.render(Mensa::View::Component.new(table))
    end

    # Column order and visibility, as users change them with the column
    # customizer, or as saved views and browser state replay them

    def verify_layout
      names = @table.display_columns.map(&:name)

      check(:layout, nil, "reversed column order") do
        skip!("no columns are shown") if names.empty?

        verify_layout_config({column_order: names.reverse}, names.reverse)
      end

      check(:layout, nil, "column order listing only :#{names.last} (e.g. saved before the others were added)") do
        skip!("fewer than 2 columns are shown") if names.size < 2

        verify_layout_config({column_order: [names.last]}, [names.last] + names[0..-2],
          hint: "columns a column_order doesn't list should follow the listed ones")
      end

      check(:layout, nil, "hide each column (#{names.size})") do
        skip!("no columns are shown") if names.empty?

        errors = names.filter_map do |name|
          savepoint { verify_layout_config({hidden_columns: [name]}, names - [name]) }
          nil
        rescue StandardError, ScriptError => e
          ":#{name}: #{e.is_a?(Failure) ? e.message : "#{e.class}: #{e.message}"}"
        end
        raise Failure, errors.join("\n") if errors.any?
      end

      check(:layout, nil, "hide all columns") do
        skip!("no columns are shown") if names.empty?

        verify_layout_config({hidden_columns: names}, [])
      end
    end

    # Builds the table with +config+, checks the columns it shows, renders it
    # and exports it
    def verify_layout_config(config, expected, hint: nil)
      table = build_table(config)
      shown = table.display_columns.map(&:name)
      unless shown == expected
        raise Failure, "shows columns #{shown.inspect}, expected #{expected.inspect}#{"\n#{hint}" if hint}"
      end

      render_page(table)
      verify_export(config, columns_required: expected.any?) if @table.exportable?
    end

    # Everything a user can combine at once: search, a filter on every
    # column, sorting on every column and grouping with aggregates
    def verify_combined
      check(:combined, nil, "search, filters, sorting and grouping together") do |c|
        config = {query: search_term, filters: combined_filters}
        config[:order] = @table.columns.select { |column| column.sortable? && !column.internal? }.to_h { |column| [column.name, :asc] }

        groupable = @table.columns.find(&:groupable?)
        if groupable && @table.scope.is_a?(ActiveRecord::Relation)
          config[:group_by] = groupable.name
          config[:aggregates] = @table.columns.select(&:aggregatable?).reject(&:internal?).to_h { |column| [column.name, column.aggregates.first] }
        end

        table = build_table(config)
        c.sql = table.selected_scope.to_sql
        render_page(build_table(config))
      end
    end

    def combined_filters
      @table.columns.select(&:filter?).each_with_object({}) do |column, filters|
        operators = attempt { column.filter.operators } || []
        operator, _label, with_value = operators.find { |_operator, _label, with_value| with_value } ||
          operators.find { |operator, *| %i[is_empty isnt_empty].include?(operator) }
        next unless operator

        values = attempt { filter_values(column) } || [synthetic_value(column)]
        filters[column.name] = {operator: operator, value: filter_value(column, operator, with_value, values)}.compact
      end
    end

    # Exports, generated by Mensa::ExportJob like a user's export request,
    # for the first page of the table and of each view

    def verify_exports
      unless @table.exportable?
        check(:exports, nil, "csv") { skip!("exportable false") }
        return
      end

      check(:exports, nil, export_format) { verify_export({}) }

      @table.system_views.each do |view|
        # The browser sends the view's state along with the export request
        config = (view.config || {}).deep_symbolize_keys.slice(:filters, :column_order, :hidden_columns, :group_by, :order)
        next if config.empty?

        check(:exports, view.id, export_format) { verify_export(config) }
      end

      return unless @table.supports_custom_views?

      saved_views.each do |view|
        check(:exports, "saved view #{view.id}", export_format) { verify_export({}, table_view: view) }
      end
    end

    def export_format
      @table.export_with_password? ? "csv (zip with password)" : "csv"
    end

    def verify_export(config, table_view: nil, columns_required: true)
      config = JSON.parse({params: params.presence, page: 1}.compact.merge(config).to_json)
      export = Mensa::Export.new(
        table_name: table_name, table_view_id: table_view&.id, format: "plain_csv", scope: "current_page",
        config: config, created_at: Time.current
      )

      file, filename, content_type = Mensa::ExportJob.new.generate_file(export)
      raise Failure, "the export job generated no file" unless file

      data = file.read
      file.close!
      csv = (content_type == "application/zip") ? unzip(data, export.password) : data
      raise Failure, "#{filename} is empty" if csv.blank? && columns_required

      expected = build_table((table_view&.config || {}).deep_symbolize_keys.merge(config.deep_symbolize_keys))
      headers = expected.display_columns.map { |column| column.name.to_s }
      lines = CSV.parse(csv.force_encoding(Encoding::UTF_8).delete_prefix("﻿"))
      raise Failure, "the export has no columns" if headers.empty? && columns_required
      return if headers.empty?

      raise Failure, "the export has headers #{lines.first.inspect}, expected #{headers.inspect}" unless lines.first == headers

      records = expected.rows.size
      raise Failure, "the export has #{lines.size - 1} records, expected #{records}" unless lines.size - 1 == records
    end

    def unzip(data, password)
      require "zip"

      Zip::InputStream.open(StringIO.new(data), decrypter: Zip::TraditionalDecrypter.new(password)) do |zip|
        zip.get_next_entry
        zip.read
      end
    end

    # Grouping and aggregates

    def verify_grouping
      groupable = @table.columns.select(&:groupable?)
      relation = @table.scope.is_a?(ActiveRecord::Relation)

      if @table.config[:group_by].present? || @table.config[:aggregates].present?
        check(:grouping, nil, "configured group_by/aggregates") do
          problems = grouping_problems(@table, @table.config)
          raise Failure, problems.join("\n") if problems.any?

          render_page(build_table)
        end
      end

      groupable.each do |column|
        check(:grouping, column.name, "group by") do
          skip!("the scope is not an ActiveRecord::Relation") unless relation

          render_page(build_table(group_by: column.name, aggregates: {}))
        end
      end

      @table.columns.select(&:aggregatable?).reject(&:internal?).each do |column|
        column.aggregates.each do |function|
          check(:grouping, column.name, function.to_s) do
            skip!("no groupable column to group by") if groupable.empty?
            skip!("the scope is not an ActiveRecord::Relation") unless relation

            render_page(build_table(group_by: groupable.first.name, aggregates: {column.name => function}))
          end
        end
      end
    end

    # Mensa ignores a group_by or aggregates it can't use, report them instead
    def grouping_problems(table, config)
      problems = []

      group_by = config[:group_by].presence
      if group_by && !table.column(group_by)&.groupable?
        problems << "group_by :#{group_by} is not a groupable column (groupable true, with an SQL attribute)"
      end

      (config[:aggregates].presence || {}).to_h.each do |name, function|
        column = table.column(name)
        unless column&.aggregates&.map(&:to_s)&.include?(function.to_s)
          problems << "aggregates #{name}: :#{function} is not allowed, the column allows #{column&.aggregates.presence&.inspect || "none"}"
        end
      end

      problems
    end

    # Views

    def verify_views
      @table.system_views.each do |view|
        check(:views, view.id, view.name.to_s) do
          config = (view.config || {}).deep_symbolize_keys
          problems = config_problems(config)
          raise Failure, problems.join("\n") if problems.any?

          render_page(build_table(config), view: view)
        end
      end

      unless @table.supports_custom_views?
        check(:views, "custom view", "create") { skip!("supports_custom_views is off") }
        return
      end

      verify_custom_view

      saved_views.each do |view|
        check(:views, "saved view #{view.id}", view.name.to_s) { render_page(build_table((view.config || {}).deep_symbolize_keys), view: view) }
      end
    end

    # Creates a custom view like a user saving the table's state would, but
    # doesn't save it: it's validated, then replayed and exported like a saved
    # view.
    def verify_custom_view
      check(:views, "custom view", "create and replay (not saved)") do |c|
        skip!("custom views are owned by Current.user, give the verifier a user:") if @table.current_user.blank?

        view = custom_view
        raise Failure, "the view is invalid: #{view.errors.full_messages.to_sentence}" unless view.valid?

        c.name = "create and replay #{view.config.keys.join(", ")} (not saved)"
        # Like Mensa::TablesController#show and the views controller
        render_page(build_table(view.config.deep_transform_keys(&:to_sym)), view: view)
      end

      return unless @table.exportable? && @table.current_user.present?

      check(:exports, "custom view", export_format) do
        verify_export(custom_view.config.deep_symbolize_keys.slice(:filters, :column_order, :hidden_columns, :group_by, :order))
      end
    end

    # A view as Mensa::Tables::ViewsController#create builds it from the
    # table's state in the browser
    def custom_view
      Mensa::TableView.new(
        table_name: table_name,
        name: "Mensa::Verifier",
        description: "Created by Mensa::Verifier, not saved",
        config: JSON.parse(custom_view_config.to_json),
        user: @table.current_user
      )
    end

    def custom_view_config
      @custom_view_config ||= begin
        columns = @table.display_columns
        sortable = columns.find(&:sortable?)
        groupable = @table.columns.find(&:groupable?)

        config = {query: search_term, filters: combined_filters.first(2).to_h}
        config[:order] = {sortable.name => :desc} if sortable
        config[:column_order] = columns.map(&:name).reverse
        config[:hidden_columns] = [columns.last.name] if columns.size > 1
        if groupable && @table.scope.is_a?(ActiveRecord::Relation)
          config[:group_by] = groupable.name
          aggregatable = @table.columns.reject(&:internal?).find(&:aggregatable?)
          config[:aggregates] = {aggregatable.name => aggregatable.aggregates.first} if aggregatable
        end
        config
      end
    end

    def saved_views
      Mensa::TableView.where(table_name: table_name, user: [nil, @table.current_user].uniq).order(:created_at).limit(25).to_a
    end

    # References to columns (in a view or the table's defaults) that Mensa
    # would silently ignore
    def config_problems(config)
      names = @table.columns.map(&:name)
      problems = []

      (config[:filters] || {}).each_key { |name| problems << "filter on unknown column :#{name}" unless names.include?(name.to_sym) }
      Array(config[:hidden_columns]).each { |name| problems << "hidden_columns has unknown column :#{name}" unless names.include?(name.to_sym) }
      Array(config[:column_order]).each { |name| problems << "column_order has unknown column :#{name}" unless names.include?(name.to_sym) }
      (config[:order] || {}).each do |name, direction|
        problems << "order on unknown column :#{name}" unless names.include?(name.to_sym) || @table.model.column_names.include?(name.to_s)
        problems << "order :#{name} has direction #{direction.inspect}, expected :asc or :desc" unless %w[asc desc].include?(direction.to_s.downcase)
      end
      problems + grouping_problems(@table, config)
    end

    # Transaction and context

    def read_only_transaction
      ActiveRecord::Base.while_preventing_writes do
        ActiveRecord::Base.transaction(requires_new: true) do
          connection = ActiveRecord::Base.connection
          connection.execute("SET LOCAL transaction_read_only = on") if connection.adapter_name.downcase.include?("postg")
          yield
          raise ActiveRecord::Rollback
        end
      end
    end

    def with_current_attributes(&)
      attributes = context.symbolize_keys
      attributes[:user] = user if user
      attributes[:account] = account if account
      return yield if attributes.empty?

      raise ArgumentError, "Mensa::Verifier: setting #{attributes.keys.join(", ")} needs a Current class" unless defined?(::Current)

      unknown = attributes.keys.reject { |key| ::Current.respond_to?(:"#{key}=") }
      raise ArgumentError, "Mensa::Verifier: Current has no attribute(s) #{unknown.join(", ")}" if unknown.any?

      # The stored values, Current.set would restore what the getters return
      stored = ::Current.attributes.symbolize_keys if ::Current.respond_to?(:attributes)
      previous = attributes.keys.to_h { |key| [key, stored ? stored[key] : ::Current.public_send(key)] }
      attributes.each { |key, value| ::Current.public_send(:"#{key}=", value) }
      yield
    ensure
      previous&.each { |key, value| ::Current.public_send(:"#{key}=", value) }
    end
  end
end
