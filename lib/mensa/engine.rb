require "pagy"
require "satis"
require "textacular"
require "caxlsx_rails"
require "slim"
require "tailwindcss-rails"
require "importmap-rails"
require "turbo-rails"
require "stimulus-rails"

module Mensa
  class Engine < ::Rails::Engine
    isolate_namespace Mensa

    initializer "mensa.assets" do |app|
      app.config.assets.paths << root.join("app/javascript")
      app.config.assets.paths << root.join("app/components")
      app.config.assets.paths << Mensa::Engine.root.join("vendor/javascript")
      app.config.assets.precompile += %w[mensa_manifest]
    end

    initializer "mensa.importmap", before: "importmap" do |app|
      app.config.importmap.paths << root.join("config/importmap.rb")
      app.config.importmap.cache_sweepers << root.join("app/javascript")
      app.config.importmap.cache_sweepers << root.join("app/components")
      app.config.importmap.cache_sweepers << Mensa::Engine.root.join("vendor/javascript")
    end

    initializer "mensa.helper" do
      Rails.application.reloader.to_prepare do
        ActiveSupport.on_load(:action_controller) do
          Satis.add_helper(:table, ::Mensa::Table::Component)
        end
      end
    end
  end
end
