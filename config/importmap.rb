pin "mensa", to: "mensa/application.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from Mensa::Engine.root.join("app/javascript/mensa/controllers"), under: "controllers", to: "mensa/controllers"
