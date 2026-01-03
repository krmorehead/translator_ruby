Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get "hello/index"
      post "translate", to: "translation#translate"
      post "translate_text", to: "translation#translate_text"
      post "research", to: "research#create"
      
      # Checkpoint management routes
      resources :checkpoints, only: [:create, :index, :show] do
        member do
          get "diff"
          post "rollback"
        end
        collection do
          get "candidates"
          get "current"
        end
      end
    end

    # Agent configuration routes
    namespace :agent do
      get "config", to: "agent_config#show"
      post "config/validate", to: "agent_config#validate"
      post "config/test", to: "agent_config#test"
    end

    # Agent session management routes (chat, thoughts, memory, context)
    resources :agent_sessions, param: :session_id do
      member do
        get "messages", to: "agent_sessions#list_messages"
        post "messages", to: "agent_sessions#create_message"
        get "thoughts", to: "agent_sessions#list_thoughts"
        get "memories", to: "agent_sessions#list_memories"
        delete "memories/clear", to: "agent_sessions#clear_memory"
        get "actions", to: "agent_sessions#list_actions"
      end
    end
  end
  # DnD Chat API
  post "/dnd_chat/sessions", to: "dnd_chat#create_session"
  get "/dnd_chat/messages", to: "dnd_chat#messages"
  post "/dnd_chat/messages", to: "dnd_chat#create_message"
  get "/dnd_chat/messages/contract", to: "dnd_chat#messages_contract"

  get "/dnd_chat/agent", to: "dnd_chat#agent"
  get "/dnd_chat/agent/contract", to: "dnd_chat#agent_contract"
  get "/dnd_chat/agent/version/contract", to: "dnd_chat#agent_version_contract"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Project Planning routes
  get "/project_planning", to: "project_planning#spa"
  post "/project_planning/create", to: "project_planning#create"

  # Daedalus (Execution Plan Generation) routes
  get "/daedalus", to: "daedalus#spa"
  post "/daedalus/create", to: "daedalus#create"

  # Sisyphus Agent Worker routes
  get "/sisyphus", to: "sisyphus#index"
  
  # Unified Agent Workspace (serves same SPA for both)
  get "/agent", to: "daedalus#spa"
  
  # Checkpoint Manager SPA
  get "/checkpoints", to: "sisyphus#index"  # Reuse Sisyphus controller for SPA
  
  # Sisyphus API routes
  post "/api/sisyphus/executions", to: "sisyphus#create_execution"
  get "/api/sisyphus/executions", to: "sisyphus#list_executions"
  get "/api/sisyphus/executions/:execution_id/stream", to: "sisyphus#stream_execution"
  get "/api/sisyphus/executions/:execution_id", to: "sisyphus#show_execution"
  delete "/api/sisyphus/executions/:execution_id", to: "sisyphus#cancel_execution"
  
  # Approval routes
  get "/api/sisyphus/approvals/pending", to: "sisyphus#pending_approvals"
  get "/api/sisyphus/approvals/:request_id", to: "sisyphus#show_approval"
  post "/api/sisyphus/approvals/:request_id/approve", to: "sisyphus#approve_request"
  post "/api/sisyphus/approvals/:request_id/reject", to: "sisyphus#reject_request"
  
  # File system operations
  get "/api/sisyphus/filesystem/tree", to: "sisyphus#file_tree"
  get "/api/sisyphus/filesystem/read", to: "sisyphus#read_file"
  get "/api/sisyphus/filesystem/search", to: "sisyphus#search_files"
  
  # Configuration
  get "/api/sisyphus/config", to: "sisyphus#show_config"
  post "/api/sisyphus/config/validate", to: "sisyphus#validate_config"
  post "/api/sisyphus/config/test", to: "sisyphus#test_connection"
  
  # React SPA entry (built frontend/dist)
  root to: "dnd_chat#spa"
  get "/inspector", to: "dnd_chat#spa"
end
