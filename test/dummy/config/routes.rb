Rails.application.routes.draw do
  mount Checkpoint::Rails::Engine => "/checkpoint-rails"
end
