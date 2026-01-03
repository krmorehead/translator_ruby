# frozen_string_literal: true

# Domain model representing a memory section snapshot.
# Captures state of a specific memory section at a point in time.
#
# Strict OOP principles:
# - Immutable value object
# - Validation in constructor
# - No hash access patterns
class MemorySection
  attr_reader :section_name, :content, :timestamp, :metadata

  # Initialize a new memory section
  # @param section_name [String, Symbol] Section name (e.g., :findings, :context_chain)
  # @param content [Object] Section content (array, hash, or other serializable data)
  # @param timestamp [Time, String] Snapshot timestamp
  # @param metadata [Hash] Additional metadata
  def initialize(section_name:, content:, timestamp:, metadata: {})
    raise ArgumentError, "section_name is required" if section_name.nil? || section_name.to_s.empty?
    raise ArgumentError, "content is required" if content.nil?
    raise ArgumentError, "timestamp is required" if timestamp.nil?
    raise ArgumentError, "metadata must be a Hash" unless metadata.nil? || metadata.is_a?(Hash)

    @section_name = section_name.to_sym
    @content = deep_freeze(content)
    @timestamp = parse_time(timestamp)
    @metadata = (metadata || {}).dup.freeze
    
    freeze
  end

  # Check if section is empty
  # @return [Boolean]
  def empty?
    @content.nil? || 
    (@content.respond_to?(:empty?) && @content.empty?) ||
    (@content.respond_to?(:size) && @content.size == 0)
  end

  # Get content size
  # @return [Integer, nil]
  def size
    return nil unless @content.respond_to?(:size)
    @content.size
  end

  # Serialize to hash for API responses
  # @return [Hash]
  def to_h
    {
      section_name: @section_name.to_s,
      content: @content,
      timestamp: @timestamp.iso8601,
      metadata: @metadata,
      size: size,
      empty: empty?
    }
  end
  alias_method :to_json, :to_h

  # Create memory section from hash
  # @param data [Hash] Memory section data
  # @return [MemorySection]
  def self.from_h(data)
    raise ArgumentError, "data must be a Hash" unless data.is_a?(Hash)
    
    new(
      section_name: data[:section_name] || data["section_name"],
      content: data[:content] || data["content"],
      timestamp: data[:timestamp] || data["timestamp"],
      metadata: data[:metadata] || data["metadata"] || {}
    )
  end

  private

  # Parse time from various formats
  # @param value [Time, String, Integer] Time value
  # @return [Time]
  def parse_time(value)
    return value if value.is_a?(Time)
    return Time.at(value) if value.is_a?(Integer)
    return Time.parse(value) if value.is_a?(String)
    raise ArgumentError, "Invalid time value: #{value}"
  end

  # Deep freeze nested structures
  # @param obj [Object] Object to freeze
  # @return [Object] Frozen object
  def deep_freeze(obj)
    case obj
    when Hash
      obj.each { |k, v| deep_freeze(v) }
      obj.freeze
    when Array
      obj.each { |v| deep_freeze(v) }
      obj.freeze
    else
      obj.freeze if obj.respond_to?(:freeze)
      obj
    end
  end
end








