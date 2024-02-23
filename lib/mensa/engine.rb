module Mensa
  class Engine < ::Rails::Engine
    isolate_namespace Mensa

    initializer 'mensa.helper' do
      Rails.application.reloader.to_prepare do
        ActiveSupport.on_load(:action_controller) do
          Satis.add_helper(:mensa, ::Mensa::Table::Component)
        end
      end
    end
  end
end
