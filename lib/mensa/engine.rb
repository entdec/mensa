require 'pagy'
require 'satis'
require 'textacular'
require 'caxlsx_rails'
require 'slim'
require 'tailwindcss-rails'
require "importmap-rails"
require "turbo-rails"
require "stimulus-rails"

module Mensa
  class Engine < ::Rails::Engine
    isolate_namespace Mensa

    initializer 'mensa.assets' do |app|
      app.config.assets.paths << root.join("app/javascript")
      app.config.assets.precompile += %w[mensa_manifest]
    end

    initializer 'mensa.importmap', before: "importmap" do |app|
      app.config.importmap.paths << root.join("config/initializers/importmap.rb")
      app.config.importmap.cache_sweepers << root.join("app/javascript")
      app.config.importmap.cache_sweepers << root.join("app/components")
    end

    initializer 'mensa.helper' do
      Rails.application.reloader.to_prepare do
        ActiveSupport.on_load(:action_controller) do
          Satis.add_helper(:mensa, ::Mensa::Table::Component)
        end
      end
    end
  end
end
