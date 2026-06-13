Rails.application.routes.draw do
  root to: "users#index"
  resources :users
  resources :customers
  resources :search_only_users, only: :index
  resources :headerless_users, only: :index
  resources :scoped_users, only: :index
  resources :non_custom_view_users, only: :index

  mount Mensa::Engine => "/mensa"
end
