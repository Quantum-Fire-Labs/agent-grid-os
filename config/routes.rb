Rails.application.routes.draw do
  resources :agents do
    resource :awakening, only: %i[create update destroy], module: :agents
    resources :conversations, only: %i[index create], module: :agents do
      resources :messages, only: %i[index create destroy], module: :conversations do
        resource :speech, only: :create, module: :messages do
          post :regenerate, on: :member
        end
      end
      resources :participants, only: %i[create destroy], module: :conversations
    end
    resources :users, only: %i[index create destroy], module: :agents
    resources :models, only: %i[index create update destroy], module: :agents
    resource :settings, only: %i[show update], module: :agents
    resources :plugins, only: %i[index create destroy], module: :agents
    resources :memories, only: %i[index edit update destroy], module: :agents
    resource :terminal, only: :show, module: :agents
  end
  resources :skills
  resources :plugins, only: %i[index show new create destroy] do
    resources :configs, only: %i[index create update destroy], controller: "plugins/configs"
  end
  resource :settings, only: :show do
    resource :profile, only: %i[show update], module: :settings
    resource :account, only: %i[show update], module: :settings
    resources :providers, module: :settings
    resources :provider_models, only: :index, module: :settings
    resources :oauth_connections, only: %i[show create destroy], module: :settings, param: :provider_name
    resource :voice, only: %i[show update], module: :settings
    resources :users, module: :settings
  end
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :chats, only: %i[index show create]

  root "chats#index"
end
