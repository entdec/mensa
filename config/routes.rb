Mensa::Engine.routes.draw do
  resources :tables do
    scope module: :tables do
      resources :filters
      resources :views, only: [:create]
      resources :batch_actions, only: [:create]
      resources :exports, only: [:index, :create] do
        member do
          get :download
        end
      end
    end
  end
end
