require "test_helper"

# A column of every type the operators depend on. The dummy schema only has
# string, integer, datetime and uuid columns, the others are attributes with
# a type.
class OperatorTypesTable < Mensa::Base
  definition do
    model Customer

    column(:name)                     # string
    column(:number_of_employees)      # integer
    column(:created_at)               # datetime
    column(:id) do                    # uuid
      sortable false
    end
    column(:notes) do
      attribute "customers.name"
      type :text
    end
    column(:weight) do
      attribute "customers.number_of_employees::float"
      type :float
    end
    column(:price) do
      attribute "customers.market_cap::numeric / 100"
      type :decimal
    end
    column(:listed) do
      attribute "customers.stock_symbol IS NOT NULL"
      type :boolean
    end
    column(:founded_on) do
      attribute "customers.created_at::date"
      type :date
    end
    column(:opens_at) do
      attribute "customers.created_at::time"
      type :time
    end
    column(:settings) do
      attribute "jsonb_build_object('country', customers.country)"
      type :jsonb
    end
    column(:raw_settings) do
      attribute "json_build_object('country', customers.country)"
      type :json
      sortable false
    end
    column(:label) do                 # untyped attribute, treated as text
      attribute "customers.name || ' ' || customers.country"
    end
    column(:flag) do
      attribute "customers.stock_symbol IS NOT NULL"
      type :boolean
      filter do
        operators [:is, :matches, :gt]
      end
    end
  end
end

class FilterOperatorsTest < ActiveSupport::TestCase
  TEXT = %i[is isnt matches does_not_match is_duplicate is_empty isnt_empty].freeze
  NUMBER = %i[is isnt gt gteq lt lteq is_duplicate is_empty isnt_empty].freeze
  POINT_IN_TIME = %i[gt gteq lt lteq is_duplicate is_empty isnt_empty].freeze
  EQUALITY = %i[is isnt is_duplicate is_empty isnt_empty].freeze

  def operators(column_name)
    OperatorTypesTable.new.column(column_name).filter.operators.map(&:first)
  end

  test "string columns get the text operators" do
    assert_equal TEXT, operators(:name)
  end

  test "text columns get the text operators" do
    assert_equal TEXT, operators(:notes)
  end

  test "untyped attributes are treated as text" do
    assert_equal TEXT, operators(:label)
  end

  test "integer columns get the number operators, without LIKE" do
    assert_equal NUMBER, operators(:number_of_employees)
  end

  test "float columns get the number operators, without LIKE" do
    assert_equal NUMBER, operators(:weight)
  end

  test "decimal columns get the number operators, without LIKE" do
    assert_equal NUMBER, operators(:price)
  end

  test "boolean columns get no LIKE or range operators" do
    assert_equal EQUALITY, operators(:listed)
  end

  test "date columns get the range operators, without exact matches or LIKE" do
    assert_equal POINT_IN_TIME, operators(:founded_on)
  end

  test "datetime columns get the range operators, without exact matches or LIKE" do
    assert_equal POINT_IN_TIME, operators(:created_at)
  end

  test "time columns get the number operators, without LIKE" do
    assert_equal NUMBER, operators(:opens_at)
  end

  test "uuid columns get no LIKE or range operators" do
    assert_equal EQUALITY, operators(:id)
  end

  test "jsonb columns can only be filtered on being empty or duplicate" do
    assert_equal %i[is_duplicate is_empty isnt_empty], operators(:settings)
  end

  test "json columns can only be filtered on being empty" do
    assert_equal %i[is_empty isnt_empty], operators(:raw_settings)
  end

  test "an explicit operators list is left untouched" do
    assert_equal %i[is matches gt], operators(:flag)
  end

  test "every operator offered for a type runs in SQL" do
    result = Mensa::Verifier.new(OperatorTypesTable).call
    filters = result.checks.select { |check| check.section == :filters }

    # The explicit list on :flag includes operators a boolean can't run
    assert_equal [:flag], filters.select(&:failed?).map(&:subject), result.to_s
  end

  test "time filters only take a time" do
    table = OperatorTypesTable.new(filters: {opens_at: {operator: :gt, value: "not a time"}})
    table.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("/"))

    assert_equal [], table.ordered_scope.to_a
    assert_equal "time", table.column(:opens_at).filter.input_type
  end
end
