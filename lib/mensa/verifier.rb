# frozen_string_literal: true

require "csv"
require "json"
require "stringio"
require "mensa/verifier/result"

module Mensa
  # Checks that everything a table configures works against the real database:
  # its scope, every column's SQL, sorting, rendering, filters, search, the CSV
  # export, grouping/aggregates and its views.
  #
  #   result = Mensa::Verifier.new(UsersTable, user: User.first).call
  #   result.success? # => true
  #   puts result     # per-check report
  #
  # Checks go through the same code paths as requests do (filtered_scope,
  # ordered_scope, Mensa::Cell, Mensa::ExportJob.write_csv, ...). Everything
  # runs in a read-only transaction that is rolled back, and every check in its
  # own savepoint so one failing query doesn't stop the others.
  #
  # Tables often depend on request context, give it with user:, account: and
  # context: (all set on Current while verifying), params: (the table's
  # params) or a block, which is called with the verifier before the checks.
  # Mensa.config.verifier_context supplies defaults for these.
  class Verifier
    # Records loaded for record-level checks, and per query
    SAMPLE_SIZE = 5

    class Skip < StandardError; end

    # A problem the verifier found itself, reported without the class name
    class Failure < StandardError; end

    attr_reader :table_class, :user, :account, :context, :params, :result

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

      # Verifies the tables (all under app/tables when none are given), prints
      # their reports to +io+ and returns true when all of them passed.
      # Context comes from USER_ID, ACCOUNT_ID and PARAMS (JSON) in +env+, used
      # by the mensa:verify rake tasks.
      def run(tables = nil, env: ENV, io: $stdout)
        classes = tables.present? ? Array(tables).map { |table| resolve_table_class(table) } : table_classes
        options = options_from_env(env)

        results = classes.map do |klass|
          new(klass, **options).call.tap { |result| io.puts(result, "") }
        end

        tables, others = results.partition(&:mensa_table?)
        if results.size > 1
          io.puts ["#{tables.count(&:success?)}/#{tables.size} tables passed", ("#{others.size} skipped, not a Mensa::Base subclass" if others.any?)].compact.join(", ")
        end
        results.all?(&:success?)
      end

      def options_from_env(env)
        options = {}
        options[:user] = "User".constantize.find(env["USER_ID"]) if env["USER_ID"].present?
        options[:account] = "Account".constantize.find(env["ACCOUNT_ID"]) if env["ACCOUNT_ID"].present?
        options[:params] = JSON.parse(env["PARAMS"]) if env["PARAMS"].present?
        options
      end
    end

    def initialize(table, user: nil, account: nil, context: {}, params: nil, view_context: nil, &setup)
      @table_class = self.class.resolve_table_class(table)
      defaults = default_options
      @user = user || defaults[:user]
      @account = account || defaults[:account]
      @context = (defaults[:context] || {}).merge(context || {})
      @params = params || defaults[:params] || {}
      @view_context = view_context
      @setup = setup
      @result = Result.new(@table_class)
    end

    def call
      return result if @called

      @called = true
      unless result.mensa_table?
        result.checks << Check.new(section: :loads, name: "Mensa table", status: :skipped, message: "#{table_class} does not descend from Mensa::Base")
        return result
      end

      read_only_transaction do
        with_current_attributes do
          @setup&.call(self)
          run_checks
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

    def default_options
      options = Mensa.config.verifier_context&.call(table_class)
      options.is_a?(Hash) ? options.symbolize_keys : {}
    end

    def default_host
      Rails.application.routes.default_url_options[:host] || "localhost"
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
      verify_second_page
      verify_defaults

      verify_columns
      verify_filters
      verify_search
      verify_rendering
      verify_exports
      verify_grouping
      verify_views
    end

    # Runs the block as one check in its own savepoint and records the
    # outcome. Returns the block's value, nil when the check didn't pass.
    # Quiet checks are only reported when they fail.
    def check(section, subject, name, quiet: false)
      c = Check.new(section: section, subject: subject, name: name)
      value = nil
      savepoint { value = yield(c) }
      c.status = :passed
      value
    rescue Skip => e
      c.status = :skipped
      c.message = e.message
      nil
    rescue StandardError, NotImplementedError => e
      c.status = :failed
      c.error = e
      c.message = e.is_a?(Failure) ? e.message : "#{e.class}: #{e.message}"
      c.sql = e.sql if e.respond_to?(:sql) && e.sql.present?
      nil
    ensure
      result.checks << c unless quiet && c.passed?
    end

    def skip!(reason)
      raise Skip, reason
    end

    def savepoint
      ActiveRecord::Base.transaction(requires_new: true) do
        yield
        raise ActiveRecord::Rollback
      end
    end

    # Record-level checks need loaded records
    def sample_rows!
      skip!("records could not be loaded") if @rows.nil?
      skip!("no records") if @rows.empty?

      @rows.first(SAMPLE_SIZE)
    end

    def verify_second_page
      check(:loads, nil, "load page 2") do
        skip!("records could not be loaded") if @rows.nil?
        skip!("only one page") if @table.pagy_details.pages < 2

        table = build_table
        table.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("http://#{default_host}/?page=2"))
        table.rows
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

        relation = build_table.filtered_scope.select(Arel.sql(column.attribute)).limit(1)
        c.sql = relation.to_sql
        relation.load
      end
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

          sample_rows!.each { |row| Mensa::Cell.new(row: row, column: column).render(format) }
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

        check(:filters, column.name, filter_check_name(column, operators, values)) do |c|
          errors = operators.filter_map { |operator, _label, with_value| filter_error(column, operator, filter_value(column, operator, with_value, values)) }
          next if errors.empty?

          c.sql = errors.first[:sql]
          raise Failure, errors.map { |error| error[:message] }.join("\n")
        end
      end
    end

    def filter_check_name(column, operators, values)
      "#{operators.map(&:first).join(", ")} (#{(column.filter.multiple? ? values : values.first).inspect})"
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
    rescue StandardError, NotImplementedError => e
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
      when :datetime, :timestamp, :time then Time.current.strftime("%Y-%m-%dT%H:%M")
      when :boolean then "true"
      when :uuid then SecureRandom.uuid
      else "a"
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

            relation = table.ordered_scope.limit(SAMPLE_SIZE)
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
      (@rows || []).first(SAMPLE_SIZE).each do |row|
        @table.display_columns.each do |column|
          value = row.value(column)
          return value.split.first.first(20) if value.is_a?(String) && value.split.first.present?
        end
      end
      "a"
    rescue
      "a"
    end

    # Rendering, like the app's views and Mensa's controllers do

    def verify_rendering
      check(:render, nil, "table component") { view_context.table(table_name, params: params) }
      check(:render, nil, "rows and filter pills") { render_page(build_table, view: @table.default_system_view) }

      check(:render, nil, "row link") { sample_rows!.each(&:link) } if @table.link

      return unless @table.actions?

      @table.actions.each do |action|
        check(:render, :actions, action.name.to_s) do
          sample_rows!.each { |row| view_context.render(Mensa::RowAction::Component.new(table: @table, row: row, action: action)) }
        end
      end
    end

    # What Mensa::TablesController#show renders into the table's turbo frame
    def render_page(table, view: nil)
      table.table_view = view
      view_context.render(Mensa::FilterPillList::Component.new(table: table))
      view_context.render(Mensa::View::Component.new(table))
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

    def verify_export(config, table_view: nil)
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
      raise Failure, "#{filename} is empty" if csv.blank?

      expected = build_table((table_view&.config || {}).deep_symbolize_keys.merge(config.deep_symbolize_keys))
      headers = expected.display_columns.map { |column| column.name.to_s }
      lines = CSV.parse(csv.force_encoding(Encoding::UTF_8).delete_prefix("\uFEFF"))
      raise Failure, "the export has no columns" if headers.empty?
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

      return unless @table.supports_custom_views?

      saved_views.each do |view|
        check(:views, "saved view #{view.id}", view.name.to_s) { render_page(build_table((view.config || {}).deep_symbolize_keys), view: view) }
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
