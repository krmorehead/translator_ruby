Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get "hello/index"
      post "translate", to: "translation#translate"
      post "translate_text", to: "translation#translate_text"
    end
  end
  get "/dnd_chat/messages", to: "dnd_chat#messages"
  post "/dnd_chat/messages", to: "dnd_chat#create_message"
  get "/dnd_chat/messages/contract", to: "dnd_chat#messages_contract"

  get "/dnd_chat/agent", to: "dnd_chat#agent"
  get "/dnd_chat/agent/version", to: "dnd_chat#agent_version"
  get "/dnd_chat/agent/contract", to: "dnd_chat#agent_contract"
  get "/dnd_chat/agent/version/contract", to: "dnd_chat#agent_version_contract"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # React SPA entry (built frontend/dist)
  root to: "dnd_chat#spa"
  get "/inspector", to: "dnd_chat#spa"
end
