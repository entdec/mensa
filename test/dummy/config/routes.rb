Rails.application.routes.draw do
  root to: "users#index"
  resources :users
  resources :customers
  resources :search_only_users, only: :index

  mount Mensa::Engine => "/mensa"
end
