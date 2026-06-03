Mensa::Engine.routes.draw do
  resources :tables do
    scope module: :tables do
      resources :filters
      resources :views, only: [:create]
    end
  end
end
