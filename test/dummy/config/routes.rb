Rails.application.routes.draw do
  resources :users
  mount Mensa::Engine => "/mensa"
end
