require "test_helper"
require "pry"

class DslLogicTest < ActiveSupport::TestCase
  test "it returns the quoted attribute" do
    class TestColumnDsl
      include Mensa::Config::DslLogic

      option :attribute
    end

    class TestDsl
      include Mensa::Config::DslLogic

      option :column, dsl_hash: TestColumnDsl
    end

    class SampleBase
      include Mensa::ConfigReaders

      defined_by TestDsl

      config_reader :columns

      def initialize(config = {})
        @params = config.to_h.deep_symbolize_keys
        @config = self.class.definition.merge(@params || {})
      end
    end

    class TestBase < SampleBase
      definition do
        column :first_name
        column :last_name
      end
    end

    subject = TestBase.new({})
    assert_equal "DslLogicTest::TestBase", subject.config[:name]
    assert_equal 2, subject.columns.size
    assert subject.columns.key?(:first_name)
  end

  test "internal column is a column with internal set to true" do
    subject = TestTable.new({})
    assert_equal true, subject.column(:customer_id).internal?
  end
end
