Rails.application.routes.draw do
  mount Callstacking::Rails::Engine => "/checkpoint-rails"
end
