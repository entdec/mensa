require "test_helper"
require "mensa/testing"

class VerifierBrokenColumnTable < Mensa::Base
  definition do
    model User

    column(:first_name)
    column(:broken) do
      attribute "users.no_such_column"
    end
  end
end

class VerifierBrokenFilterTable < Mensa::Base
  definition do
    model User

    column(:first_name)
    column(:role) do
      filter do
        collection -> { User.ROLES }
        scope ->(value) { where("users.no_such_column = ?", value) }
      end
    end
  end
end

class VerifierBrokenExportTable < Mensa::Base
  definition do
    model User

    column(:first_name)
    column(:email) do
      render do
        csv { |_user| raise "no csv for you" }
      end
    end
  end
end

class VerifierBrokenGroupingTable < Mensa::Base
  definition do
    model Customer

    column(:name) do
      aggregates :sum
    end
    column(:country) do
      groupable true
    end
    column(:industry)

    group_by :industry
  end
end

class VerifierHiddenColumnTable < Mensa::Base
  definition do
    model User

    column(:first_name)
    column(:email) do
      visible -> { false }
    end
  end
end

class VerifierEmptyTable < Mensa::Base
  definition do
    model User

    column(:first_name)
    column(:email)

    scope -> { User.where("1 = 0") }
  end
end

class VerifierWritingTable < Mensa::Base
  definition do
    model User

    column(:first_name) do
      render do
        html { |user| User.find(user.id).update!(first_name: "Changed") }
      end
    end
  end
end

class VerifierBrokenViewTable < Mensa::Base
  definition do
    model User

    column(:first_name)

    view :missing do
      name "Missing column"
      filter :no_such_column do
        value "x"
      end
    end
  end
end

class VerifierBrokenActionTable < Mensa::Base
  definition do
    model User

    column(:first_name)

    action :edit do
      link { |user| edit_user_path(user) }
    end
    action :archive do
      link { |user| archive_user_path(user) }
    end
  end
end

class VerifierCsvBlockTable < Mensa::Base
  definition do
    model User

    column(:email) do
      render do
        csv { |user| "#{user.email} #{user_path(user)}" }
      end
    end
  end
end

class VerifierBadDefaultsTable < Mensa::Base
  definition do
    model User

    column(:first_name)

    order no_such_column: :asc, first_name: :sideways
    column_order [:first_name, :gone]
  end
end

class VerifierTest < ActiveSupport::TestCase
  def verify(table, **options, &)
    Mensa::Verifier.new(table, **options, &).call
  end

  def find_check(result, section, subject, name)
    result.checks.find { |c| c.section == section && c.subject == subject && c.name.start_with?(name) } ||
      flunk("No #{section} check #{subject}: #{name} in\n#{result}")
  end

  test "a working table passes every check" do
    result = verify(UsersTable)

    assert result.success?, result.to_s
    assert_empty result.failures
    assert_equal %i[loads columns filters search render exports views], result.checks.map(&:section).uniq
    assert_match(/OK: \d+ passed, 0 failed/, result.to_s)
  end

  test "tables are found by class, class name and table name" do
    assert_equal UsersTable, Mensa::Verifier.new(UsersTable).table_class
    assert_equal UsersTable, Mensa::Verifier.new("UsersTable").table_class
    assert_equal UsersTable, Mensa::Verifier.new("users").table_class
    assert_equal "users", Mensa::Verifier.new(UsersTable).table_name
  end

  test "broken column SQL fails that column's checks, not the other columns'" do
    result = verify(VerifierBrokenColumnTable)

    assert_not result.success?
    select = find_check(result, :columns, :broken, "select")
    assert select.failed?
    assert_match(/no_such_column/, select.message)
    assert_match(/SELECT .*no_such_column/, select.sql)
    assert find_check(result, :columns, :broken, "sort").failed?
    assert find_check(result, :columns, :first_name, "select").passed?
    assert find_check(result, :columns, :first_name, "sort").passed?
    assert find_check(result, :loads, nil, "load first page").failed?
    assert find_check(result, :columns, :first_name, "render html").skipped?
  end

  test "a broken filter fails its filter check and shows the failing operator and SQL" do
    result = verify(VerifierBrokenFilterTable)

    check = find_check(result, :filters, :role, "is")
    assert check.failed?
    assert_match(/^is "admin": ActiveRecord::StatementInvalid/, check.message)
    assert_match(/no_such_column/, check.sql)
    assert find_check(result, :filters, :first_name, "is").passed?
    assert result.failures.all? { |c| c.subject == :role }, result.to_s
  end

  test "a broken csv render fails the export" do
    result = verify(VerifierBrokenExportTable)

    export = find_check(result, :exports, nil, "csv")
    assert export.failed?
    assert_match(/no csv for you/, export.message)
    assert find_check(result, :columns, :email, "render html").passed?
  end

  test "the csv export is skipped for tables that are not exportable" do
    result = verify(UsersNotExportableTable)

    assert result.success?, result.to_s
    assert find_check(result, :exports, nil, "csv").skipped?
  end

  test "group_by on a column that isn't groupable and failing aggregates are reported" do
    result = verify(VerifierBrokenGroupingTable)

    configured = find_check(result, :grouping, nil, "configured")
    assert configured.failed?
    assert_match(/group_by :industry is not a groupable column/, configured.message)
    assert find_check(result, :grouping, :country, "group by").passed?

    sum = find_check(result, :grouping, :name, "sum")
    assert sum.failed?
    assert_match(/sum\(character varying\)|function sum/i, sum.message)
  end

  test "grouping and aggregates of a working table pass" do
    result = verify(CustomersTable)

    grouping = result.checks.select { |c| c.section == :grouping }
    assert grouping.any?
    assert grouping.all?(&:passed?), result.to_s
  end

  test "hidden columns are skipped, not failed" do
    result = verify(VerifierHiddenColumnTable)

    assert result.success?, result.to_s
    check = find_check(result, :columns, :email, "render html")
    assert check.skipped?
    assert_equal "not visible", check.message
    assert find_check(result, :columns, :email, "select").passed?
  end

  test "tables without records run query checks and skip record checks" do
    result = verify(VerifierEmptyTable)

    assert result.success?, result.to_s
    assert find_check(result, :loads, nil, "load first page").passed?
    assert find_check(result, :columns, :email, "sort").passed?
    assert_equal "no records", find_check(result, :columns, :email, "render html").message
    assert find_check(result, :exports, nil, "csv").passed?
  end

  test "views that refer to unknown columns fail" do
    result = verify(VerifierBrokenViewTable)

    check = find_check(result, :views, :missing, "Missing column")
    assert check.failed?
    assert_match(/filter on unknown column :no_such_column/, check.message)
    assert find_check(result, :views, :default, "").passed?
  end

  test "the verifier never writes" do
    user = User.first
    result = verify(VerifierWritingTable)

    check = find_check(result, :columns, :first_name, "render html")
    assert check.failed?
    assert_match(/ReadOnlyError|read-only transaction/, check.message)
    assert_not_equal "Changed", user.reload.first_name
    assert_equal false, ActiveRecord::Base.connection.select_value("SHOW transaction_read_only") == "on"
  end

  test "tables that need params fail to build without them, and pass with them" do
    result = verify(CustomerUsersTable)
    assert find_check(result, :loads, nil, "build table").failed?
    assert_equal ["remaining checks"], result.skips.map(&:name)

    assert verify(CustomerUsersTable, params: {customer_id: customers(:asml).id}).success?
  end

  test "context is set on Current while verifying and the setup block is called" do
    seen = nil
    Current.user = users(:asml_user)
    verify(UsersTable, context: {user: users(:sap_user)}) { |verifier| seen = [verifier, Current.attributes[:user]] }

    assert_kind_of Mensa::Verifier, seen.first
    assert_equal users(:sap_user), seen.last
    assert_equal users(:asml_user), Current.attributes[:user]
  ensure
    Current.reset
  end

  test "unknown Current attributes raise" do
    error = assert_raises(ArgumentError) { verify(UsersTable, account: Customer.first) }
    assert_match(/Current has no attribute\(s\) account/, error.message)
  end

  test "Mensa.config.verifier_context supplies default options" do
    Mensa.config.verifier_context = ->(table_class) { {params: {customer_id: customers(:asml).id}} if table_class == CustomerUsersTable }

    assert verify(CustomerUsersTable).success?
  ensure
    Mensa.config.verifier_context = nil
  end

  test "run prints the reports and returns whether all tables passed" do
    io = StringIO.new

    assert Mensa::Verifier.run(["users", "customer_users"], env: {"PARAMS" => {customer_id: customers(:asml).id}.to_json}, io: io)
    assert_match(/^UsersTable$/, io.string)
    assert_match(%r{2/2 tables passed}, io.string)

    assert_not Mensa::Verifier.run(["customer_users"], env: {}, io: StringIO.new)
  end

  test "table_classes finds the tables in app/tables" do
    classes = Mensa::Verifier.table_classes

    assert_includes classes, UsersTable
    assert_includes classes, CustomersTable
    assert_not_includes classes, VerifierBrokenColumnTable
  end

  test "assert_mensa_table_valid passes for a working table and fails with the report" do
    assert_mensa_table_valid UsersTable

    error = assert_raises(Minitest::Assertion) { assert_mensa_table_valid VerifierBrokenColumnTable }
    assert_match(/✗ broken: select/, error.message)
    assert_match(/FAILED: /, error.message)
  end

  test "the be_a_valid_mensa_table matcher" do
    extend Mensa::Testing::Matchers

    matcher = be_a_valid_mensa_table
    assert matcher.matches?(UsersTable)
    assert_equal "be a valid Mensa table", matcher.description

    matcher = be_a_valid_mensa_table(params: {})
    assert_not matcher.matches?(VerifierBrokenFilterTable)
    assert_match(/✗ role: /, matcher.failure_message)
  end

  test "row actions are rendered and a broken one fails on its own" do
    result = verify(VerifierBrokenActionTable)

    assert find_check(result, :render, :actions, "edit").passed?, result.to_s
    archive = find_check(result, :render, :actions, "archive")
    assert archive.failed?
    assert_match(/archive_user_path/, archive.message)
  end

  test "the table component, rows and filter pills render" do
    result = verify(UsersTable)

    %w[table\ component rows\ and\ filter\ pills row\ link].each do |name|
      assert find_check(result, :render, nil, name.delete("\\")).passed?
    end
  end

  test "exports go through the export job, also for views and with a password" do
    assert find_check(verify(DefaultFilteredUsersTable), :exports, :default, "csv").passed?
    assert find_check(verify(UsersExportWithPasswordTable), :exports, nil, "csv (zip with password)").passed?
    assert find_check(verify(VerifierCsvBlockTable), :exports, nil, "csv").passed?
  end

  test "both search modes run" do
    configured = Mensa.config.search
    result = verify(UsersTable)

    assert find_check(result, :search, nil, "basic").passed?
    assert find_check(result, :search, nil, "fuzzy").passed?
    assert_equal configured, Mensa.config.search
  end

  test "the second page is loaded when there is one" do
    assert find_check(verify(UsersTable), :loads, nil, "load page 2").passed?
    assert_equal "only one page", find_check(verify(VerifierEmptyTable), :loads, nil, "load page 2").message
  end

  test "table defaults that refer to unknown columns fail" do
    check = find_check(verify(VerifierBadDefaultsTable), :loads, nil, "configured")

    assert check.failed?
    assert_match(/order on unknown column :no_such_column/, check.message)
    assert_match(/order :first_name has direction :sideways/, check.message)
    assert_match(/column_order has unknown column :gone/, check.message)
  end

  test "is_current is skipped when Current has no value" do
    Current.instance.define_singleton_method(:customer_name) { nil }
    result = verify(UsersTable)

    check = find_check(result, :filters, :customer_name, "is_current")
    assert check.skipped?
    assert_match(/Current.customer_name is nil/, check.message)
    assert_not_includes find_check(result, :filters, :customer_name, "is,").name, "is_current"
    assert result.success?, result.to_s
  ensure
    ActiveSupport::CurrentAttributes.clear_all
  end

  test "the rake tasks print the report and exit non-zero on failures" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("mensa:verify")
    task = Rake::Task["mensa:verify"]

    out, _err = capture_io { task.invoke("users") }
    assert_match(/^UsersTable$.*^OK: /m, out)

    task.reenable
    error = assert_raises(SystemExit) { capture_io { task.invoke("verifier_broken_column") } }
    assert_equal 1, error.status
  ensure
    task&.reenable
  end

  test "classes that aren't Mensa tables are skipped" do
    result = verify(User)

    assert result.success?
    assert_not result.mensa_table?
    assert_equal ["User does not descend from Mensa::Base"], result.skips.map(&:message)
    assert_equal "User\n  - skipped: User does not descend from Mensa::Base", result.to_s
    assert verify("TableFormatting").skips.any?
  end

  test "verify_all reports what isn't a Mensa table in app/tables as skipped" do
    assert_includes Mensa::Verifier.table_classes, TableFormatting

    io = StringIO.new
    Mensa::Verifier.run([UsersTable, TableFormatting], env: {}, io: io)
    assert_match(/^TableFormatting\n  - skipped: TableFormatting does not descend from Mensa::Base/, io.string)
    assert_match(%r{^1/1 tables passed, 1 skipped, not a Mensa::Base subclass$}, io.string)
  end
end
