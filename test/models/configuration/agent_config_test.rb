# frozen_string_literal: true

require "test_helper"

module Configuration
  class AgentConfigTest < ActiveSupport::TestCase
    def setup
      @cap1 = CapabilityConfig.new(
        name: :general_llm,
        model_name: "model1",
        port: 8001,
        max_context: 1000,
        base_url: "URL1"
      )

      @cap2 = CapabilityConfig.new(
        name: :tool_calling,
        model_name: "model2",
        port: 8002,
        max_context: 2000,
        base_url: "URL2"
      )

      @capabilities = {
        general_llm: @cap1,
        tool_calling: @cap2
      }

      @environment = {
        "API_KEY" => "***",
        "LLM_URL" => "http://localhost"
      }
    end

    speed_profile :fast
    test "initializes with valid parameters" do
      config = AgentConfig.new(
        capabilities: @capabilities,
        environment: @environment
      )

      assert_equal @capabilities, config.capabilities
      assert_equal @environment, config.environment
    end

    speed_profile :fast
    test "initializes with empty environment by default" do
      config = AgentConfig.new(
        capabilities: @capabilities,
        environment: {}
      )

      assert_equal @capabilities, config.capabilities
      assert_equal({}, config.environment)
    end

    speed_profile :fast
    test "capability returns capability by name" do
      config = AgentConfig.new(
        capabilities: @capabilities,
        environment: {}
      )

      assert_equal @cap1, config.capability(:general_llm)
      assert_equal @cap2, config.capability(:tool_calling)
    end

    speed_profile :fast
    test "capability returns nil for unknown name" do
      config = AgentConfig.new(
        capabilities: @capabilities,
        environment: {}
      )

      assert_nil config.capability(:unknown)
    end

    speed_profile :fast
    test "capability_names returns all capability names" do
      config = AgentConfig.new(
        capabilities: @capabilities,
        environment: {}
      )

      names = config.capability_names

      assert_includes names, :general_llm
      assert_includes names, :tool_calling
      assert_equal 2, names.size
    end

    speed_profile :fast
    test "capability? checks if capability exists" do
      config = AgentConfig.new(
        capabilities: @capabilities,
        environment: {}
      )

      assert config.capability?(:general_llm)
      assert config.capability?(:tool_calling)
      assert_not config.capability?(:unknown)
    end

    speed_profile :fast
    test "to_h serializes all attributes" do
      config = AgentConfig.new(
        capabilities: @capabilities,
        environment: @environment
      )

      hash = config.to_h

      assert hash.key?(:capabilities)
      assert hash.key?(:environment)
      assert_equal 2, hash[:capabilities].size
      assert hash[:capabilities][:general_llm].is_a?(Hash)
      assert_equal @environment, hash[:environment]
    end

    speed_profile :fast
    test "from_h deserializes from hash" do
      hash = {
        capabilities: {
          general_llm: {
            name: :general_llm,
            model_name: "model1",
            port: 8001,
            max_context: 1000,
            base_url: "URL1"
          }
        },
        environment: @environment
      }

      config = AgentConfig.from_h(**hash)

      assert config.capability?(:general_llm)
      assert_equal @environment, config.environment
    end

    speed_profile :fast
    test "from_h handles string keys" do
      hash = {
        "capabilities" => {
          "general_llm" => {
            "name" => "general_llm",
            "model_name" => "model1",
            "port" => 8001,
            "max_context" => 1000,
            "base_url" => "URL1"
          }
        },
        "environment" => @environment
      }

      config = AgentConfig.from_h(**hash.deep_symbolize_keys)

      assert config.capability?(:general_llm)
    end

    speed_profile :fast
    test "round-trip serialization preserves data" do
      original = AgentConfig.new(
        capabilities: @capabilities,
        environment: @environment
      )

      hash = original.to_h
      restored = AgentConfig.from_h(**hash)

      assert_equal original.capability_names.sort, restored.capability_names.sort
      assert_equal original.environment, restored.environment

      original.capability_names.each do |name|
        orig_cap = original.capability(name)
        rest_cap = restored.capability(name)

        assert_equal orig_cap.name, rest_cap.name
        assert_equal orig_cap.model_name, rest_cap.model_name
        assert_equal orig_cap.port, rest_cap.port
      end
    end
  end
end

