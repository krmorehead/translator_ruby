# frozen_string_literal: true

require "test_helper"

module Configuration
  class CapabilityConfigTest < ActiveSupport::TestCase
    speed_profile :fast
    test "initializes with valid parameters" do
      # Following OpenAI API format
      config = CapabilityConfig.new(
        name: :general_llm,
        model: "./vllm/models/qwen3_32B",
        provider: "vllm",
        port: 52003,
        max_context: 64000,
        base_url: "LLM_URL"
      )

      assert_equal :general_llm, config.name
      assert_equal "./vllm/models/qwen3_32B", config.model
      assert_equal "vllm", config.provider
      assert_equal 52003, config.port
      assert_equal 64000, config.max_context
      assert_equal "LLM_URL", config.base_url
    end

    speed_profile :fast
    test "validates name cannot be empty" do
      error = assert_raises(ArgumentError) do
        CapabilityConfig.new(
          name: :"",
          model: "model",
          provider: "vllm",
          port: 8000,
          max_context: 1000,
          base_url: "url"
        )
      end
      assert_match(/name cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates model cannot be empty" do
      error = assert_raises(ArgumentError) do
        CapabilityConfig.new(
          name: :test,
          model: "",
          provider: "vllm",
          port: 8000,
          max_context: 1000,
          base_url: "url"
        )
      end
      assert_match(/model cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates provider cannot be empty" do
      error = assert_raises(ArgumentError) do
        CapabilityConfig.new(
          name: :test,
          model: "model",
          provider: "",
          port: 8000,
          max_context: 1000,
          base_url: "url"
        )
      end
      assert_match(/provider cannot be empty/, error.message)
    end

    speed_profile :fast
    test "validates port must be in valid range" do
      error = assert_raises(ArgumentError) do
        CapabilityConfig.new(
          name: :test,
          model: "model",
          provider: "vllm",
          port: 70000,
          max_context: 1000,
          base_url: "url"
        )
      end
      assert_match(/port must be between/, error.message)
    end

    speed_profile :fast
    test "validates max_context must be positive" do
      error = assert_raises(ArgumentError) do
        CapabilityConfig.new(
          name: :test,
          model: "model",
          provider: "vllm",
          port: 8000,
          max_context: -100,
          base_url: "url"
        )
      end
      assert_match(/max_context must be positive/, error.message)
    end

    speed_profile :fast
    test "validates base_url cannot be empty" do
      error = assert_raises(ArgumentError) do
        CapabilityConfig.new(
          name: :test,
          model: "model",
          provider: "vllm",
          port: 8000,
          max_context: 1000,
          base_url: ""
        )
      end
      assert_match(/base_url cannot be empty/, error.message)
    end

    speed_profile :fast
    test "to_h serializes all attributes" do
      config = CapabilityConfig.new(
        name: :test_capability,
        model: "test_model",
        provider: "vllm",
        port: 9000,
        max_context: 5000,
        base_url: "TEST_URL"
      )

      hash = config.to_h

      assert_equal :test_capability, hash[:name]
      assert_equal "test_model", hash[:model]
      assert_equal "vllm", hash[:provider]
      assert_equal 9000, hash[:port]
      assert_equal 5000, hash[:max_context]
      assert_equal "TEST_URL", hash[:base_url]
    end

    speed_profile :fast
    test "from_h deserializes from hash" do
      hash = {
        name: :test_capability,
        model: "test_model",
        provider: "vllm",
        port: 9000,
        max_context: 5000,
        base_url: "TEST_URL"
      }

      config = CapabilityConfig.from_h(**hash)

      assert_equal :test_capability, config.name
      assert_equal "test_model", config.model
      assert_equal "vllm", config.provider
      assert_equal 9000, config.port
      assert_equal 5000, config.max_context
      assert_equal "TEST_URL", config.base_url
    end

    speed_profile :fast
    test "from_h handles string keys" do
      hash = {
        "name" => "test_capability",
        "model" => "test_model",
        "provider" => "vllm",
        "port" => 9000,
        "max_context" => 5000,
        "base_url" => "TEST_URL"
      }

      config = CapabilityConfig.from_h(**hash.symbolize_keys)

      assert_equal :test_capability, config.name
      assert_equal "test_model", config.model
      assert_equal "vllm", config.provider
    end

    speed_profile :fast
    test "round-trip serialization preserves data" do
      original = CapabilityConfig.new(
        name: :test,
        model: "model",
        provider: "vllm",
        port: 8000,
        max_context: 1000,
        base_url: "url"
      )

      hash = original.to_h
      restored = CapabilityConfig.from_h(**hash)

      assert_equal original.name, restored.name
      assert_equal original.model, restored.model
      assert_equal original.provider, restored.provider
      assert_equal original.port, restored.port
      assert_equal original.max_context, restored.max_context
      assert_equal original.base_url, restored.base_url
    end
  end
end
