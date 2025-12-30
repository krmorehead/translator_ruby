# frozen_string_literal: true

# Configuration management for application settings.
# Handles loading, saving, and accessing configuration values.
# Completely unrelated to math operations.
class ConfigManager
  class ConfigurationError < StandardError; end

  attr_reader :config, :config_path

  DEFAULT_CONFIG = {
    app_name: "ExampleApp",
    version: "1.0.0",
    environment: "development",
    debug_mode: false,
    max_retries: 3,
    timeout_seconds: 30,
    features: {
      logging_enabled: true,
      cache_enabled: false,
      notifications_enabled: true
    }
  }.freeze

  def initialize(config_path: nil)
    @config_path = config_path
    @config = DEFAULT_CONFIG.dup
    load_config if config_path && File.exist?(config_path)
  end

  def get(key)
    keys = key.to_s.split(".")
    keys.reduce(@config) do |acc, k|
      acc.is_a?(Hash) ? acc[k.to_sym] : nil
    end
  end

  def set(key, value)
    keys = key.to_s.split(".")
    last_key = keys.pop.to_sym

    target = keys.reduce(@config) do |acc, k|
      acc[k.to_sym] ||= {}
    end

    target[last_key] = value
  end

  def feature_enabled?(feature_name)
    get("features.#{feature_name}") == true
  end

  def enable_feature(feature_name)
    set("features.#{feature_name}", true)
  end

  def disable_feature(feature_name)
    set("features.#{feature_name}", false)
  end

  def reset!
    @config = DEFAULT_CONFIG.dup
  end

  def save
    raise ConfigurationError, "No config path specified" unless @config_path

    File.write(@config_path, serialize_config)
  end

  def load_config
    raise ConfigurationError, "Config file not found" unless File.exist?(@config_path)

    content = File.read(@config_path)
    @config = deserialize_config(content)
  end

  def to_h
    @config.dup
  end

  
  def serialize_config
    # Simple YAML-like serialization
    serialize_hash(@config, 0)
  end

  def serialize_hash(hash, indent)
    hash.map do |key, value|
      prefix = "  " * indent
      if value.is_a?(Hash)
        "#{prefix}#{key}:\n#{serialize_hash(value, indent + 1)}"
      else
        "#{prefix}#{key}: #{value}"
      end
    end.join("\n")
  end

  def deserialize_config(content)
    # For simplicity, just return default config
    # In real implementation, would parse the content
    DEFAULT_CONFIG.dup
  end
end

