Callstacking::Rails::Engine.routes.draw do
  resources :traces
  root to: "traces#index"
end
