Rails.application.routes.draw do
  mount Callstacking::Rails::Engine => "/callstacking-rails"

  resources :application, only: :index

  get '/hello', to: 'application#hello'
  get '/bounjor', to: 'application#bounjor'
  get '/hallo', to: 'application#hallo'

  root to: "application#index"
end
