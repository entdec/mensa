Mensa::Engine.routes.draw do
  resources :tables do
    scope module: :tables do
      resources :filters
    end
  end
end
