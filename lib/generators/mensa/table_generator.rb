# frozen_string_literal: true

require "rails/generators"

module Mensa
  class TableGenerator < ::Rails::Generators::NamedBase
    desc "Generates a table"

    source_root File.expand_path("templates", __dir__)

    def copy_table_file
      template "table.rb", "app/tables/#{name}_table.rb"
    end
  end
end
