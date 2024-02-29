# frozen_string_literal: true

module Mensa
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("../templates", __FILE__)

    def create_initializer_file
      template "config/initializers/mensa.rb"
    end

    def add_route
      return if Rails.application.routes.routes.detect { |route| route.app.app == Mensa::Engine }
      route %(mount Mensa::Engine => "/mensa")
    end

    def copy_migrations
      rake "mensa:install:migrations"
    end
  end
end
