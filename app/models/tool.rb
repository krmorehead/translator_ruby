# frozen_string_literal: true

# Represents a tool that can be called by LLMs.
# Follows OOP patterns with strict type validation.
class Tool
  attr_reader :name, :description, :parameters

  # @param name [String] Tool name
  # @param description [String] Tool description
  # @param parameters [Hash] JSON schema for parameters
  def initialize(name:, description:, parameters:)
    raise TypeError, "name must be a String, got #{name.class}" unless name.is_a?(String)
    raise TypeError, "description must be a String, got #{description.class}" unless description.is_a?(String)
    raise TypeError, "parameters must be a Hash, got #{parameters.class}" unless parameters.is_a?(Hash)
    raise ArgumentError, "name cannot be empty" if name.strip.empty?
    raise ArgumentError, "description cannot be empty" if description.strip.empty?

    @name = name.freeze
    @description = description.freeze
    @parameters = parameters.freeze
    freeze
  end

  # Serialize to OpenAI function calling format
  # @return [Hash] Tool in OpenAI format
  def to_h
    {
      type: "function",
      function: {
        name: @name,
        description: @description,
        parameters: @parameters
      }
    }
  end

  # Create from OpenAI function calling hash format
  # @param hash [Hash] Tool hash in OpenAI format
  # @return [Tool] Tool object
  def self.from_h(hash)
    raise TypeError, "hash must be a Hash, got #{hash.class}" unless hash.is_a?(Hash)

    function = hash[:function] || hash["function"]
    raise ArgumentError, "hash must contain :function key" unless function

    new(
      name: function[:name] || function["name"],
      description: function[:description] || function["description"],
      parameters: function[:parameters] || function["parameters"] || {}
    )
  end
end

