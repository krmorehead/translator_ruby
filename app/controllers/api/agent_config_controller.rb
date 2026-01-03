# frozen_string_literal: true

module Api
  # Controller for agent configuration management.
  # Provides endpoints to retrieve and validate LLM configuration.
  #
  # Follows controller-service pattern - delegates to AgentConfigService.
  class AgentConfigController < ApplicationController
    # GET /api/agent/config
    # Retrieve current agent configuration
    def show
      config = AgentConfigService.get_config
      
      render json: {
        success: true,
        config: config.to_h
      }
    rescue StandardError => e
      Rails.logger.error "Failed to get config: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: {
        success: false,
        error: "Failed to retrieve configuration"
      }, status: :internal_server_error
    end

    # POST /api/agent/config/validate
    # Validate configuration changes
    #
    # Request body:
    #   {
    #     "capabilities": {
    #       "general_llm": {
    #         "model_name": "...",
    #         "port": 52003,
    #         "max_context": 64000,
    #         "base_url": "LLM_URL"
    #       }
    #     }
    #   }
    def validate
      capabilities = params.require(:capabilities)
      
      result = AgentConfigService.validate_config(capabilities: capabilities.to_unsafe_h)
      
      if result[:valid]
        render json: {
          success: true,
          valid: true
        }
      else
        render json: {
          success: true,
          valid: false,
          errors: result[:errors]
        }, status: :unprocessable_entity
      end
    rescue ActionController::ParameterMissing => e
      render json: {
        success: false,
        error: e.message
      }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error "Failed to validate config: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: {
        success: false,
        error: "Validation failed"
      }, status: :internal_server_error
    end

    # POST /api/agent/config/test
    # Test connection to an LLM capability
    #
    # Request body:
    #   {
    #     "capability_name": "general_llm"
    #   }
    def test
      capability_name = params.require(:capability_name)
      
      result = AgentConfigService.test_connection(capability_name)
      
      render json: {
        success: result[:success],
        capability_name: capability_name,
        error: result[:error]
      }
    rescue ActionController::ParameterMissing => e
      render json: {
        success: false,
        error: e.message
      }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error "Failed to test connection: #{e.message}\n#{e.backtrace.join("\n")}"
      render json: {
        success: false,
        error: "Connection test failed"
      }, status: :internal_server_error
    end
  end
end








