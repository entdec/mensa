require "test_helper"
require "pry"

class DslLogicTest < ActiveSupport::TestCase
  test "it returns the quoted attribute" do
    class TestColumnDsl # rubocop:disable Lint/ConstantDefinitionInBlock
      include Mensa::Config::DslLogic

      option :attribute
    end

    class TestDsl # rubocop:disable Lint/ConstantDefinitionInBlock
      include Mensa::Config::DslLogic

      option :column, dsl_hash: TestColumnDsl
    end

    class SampleBase # rubocop:disable Lint/ConstantDefinitionInBlock
      include Mensa::ConfigReaders

      defined_by TestDsl

      config_reader :columns

      def initialize(config = {})
        normalized_config = config.to_h.deep_symbolize_keys
        @config = self.class.definition.merge(normalized_config)
      end
    end

    class TestBase < SampleBase # rubocop:disable Lint/ConstantDefinitionInBlock
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

  test "dsl option stores false when explicitly passed" do
    class NestedDsl # rubocop:disable Lint/ConstantDefinitionInBlock
      include Mensa::Config::DslLogic

      option :enabled, default: true
    end

    class ParentDsl # rubocop:disable Lint/ConstantDefinitionInBlock
      include Mensa::Config::DslLogic

      option :name
      option :nested, dsl: NestedDsl
    end

    subject = ParentDsl.new(nil) do
      nested false
    end

    assert_equal false, subject.config[:nested]
  end

  test "internal column is a column with internal set to true" do
    subject = TestTable.new({})
    assert_equal true, subject.column(:customer_id).internal?
  end
end
