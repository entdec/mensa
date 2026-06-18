Rails.application.routes.draw do
  root to: "users#index"
  resources :users
  resources :customers
  resources :search_only_users, only: :index
  resources :headerless_users, only: :index
  resources :scoped_users, only: :index
  resources :non_custom_view_users, only: :index
  resources :no_views_users, only: :index
  resources :default_filtered_users, only: :index
  resources :users_export_with_password, only: :index

  mount Mensa::Engine => "/mensa"
end
