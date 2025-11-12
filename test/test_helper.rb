# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [File.expand_path("fixtures", __dir__)]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  ActiveSupport::TestCase.fixtures :all
end

class TestTable < Mensa::Base
  definition do
    model User

    column(:first_name)
    column(:last_name)
    column(:name) do
      attribute "CONCAT(first_name, last_name)"
    end
    column(:role) do
      filter
    end
    column :customer_id do
      internal true
    end

    link { |test| root_path }

    action :edit do
      link { |test| root_path }
    end
  end
end

class CustomerTable < Mensa::Base
  definition do
    column(:name)
    column(:country) do
      filter
    end

    link { |test| root_path }
  end
end
