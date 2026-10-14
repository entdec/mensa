# frozen_string_literal: true

require "mensa/verifier"

module Mensa
  # Test helpers on top of Mensa::Verifier, opt in with `require "mensa/testing"`.
  #
  #   assert_mensa_table_valid UsersTable, user: users(:admin)        # Minitest
  #   expect(UsersTable).to be_a_valid_mensa_table(user: admin)        # RSpec
  #
  # Both take the verifier's options (user:, account:, context:, params:)
  # and fail with its report.
  module Testing
    module Assertions
      def assert_mensa_table_valid(table, message = nil, **options, &setup)
        result = Mensa::Verifier.new(table, **options, &setup).call
        assert result.success?, -> { [message, result.to_s].compact.join("\n\n") }
        result
      end
    end

    class ValidTableMatcher
      attr_reader :result

      def initialize(**options, &setup)
        @options = options
        @setup = setup
      end

      def matches?(table)
        @result = Mensa::Verifier.new(table, **@options, &@setup).call
        @result.success?
      end

      def failure_message
        result.to_s
      end

      def failure_message_when_negated
        "expected #{result.table_class} not to be a valid Mensa table, but all its checks passed"
      end

      def description
        "be a valid Mensa table"
      end
    end

    module Matchers
      def be_a_valid_mensa_table(**options, &setup)
        ValidTableMatcher.new(**options, &setup)
      end
    end
  end
end

if defined?(Minitest::Test)
  Minitest::Test.include(Mensa::Testing::Assertions)
else
  ActiveSupport.on_load(:active_support_test_case) { include Mensa::Testing::Assertions }
end

RSpec.configure { |config| config.include(Mensa::Testing::Matchers) } if defined?(RSpec) && RSpec.respond_to?(:configure)
