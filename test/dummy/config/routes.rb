Rails.application.routes.draw do
  root to: "users#index"
  resources :users
  resources :customers

  mount Mensa::Engine => "/mensa"
end
