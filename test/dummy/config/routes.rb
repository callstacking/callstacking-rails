Rails.application.routes.draw do
  mount Callstacking::Rails::Engine => "/callstacking-rails"

  resources :application, only: :index
  root to: "application#index"
end
