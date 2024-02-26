# frozen_string_literal: true

require "mensa"

Mensa.importmap.draw do
  pin "mensa", to: "mensa/application.js", preload: true
  pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
  pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
  pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
  pin '@fortawesome/fontawesome-free', to: 'https://ga.jspm.io/npm:@fortawesome/fontawesome-free@6.1.1/js/all.js'
  pin_all_from Mensa::Engine.root.join("app/javascript/mensa/controllers"), under: "controllers", to: "mensa/controllers"
  pin_all_from Mensa::Engine.root.join("app/components")#, under: "components", to: "mensa/components"
  pin "@rails/request.js", to: "@rails--request.js.js" # @0.0.9
end