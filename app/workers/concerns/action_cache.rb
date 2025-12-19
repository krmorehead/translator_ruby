# frozen_string_literal: true

# Provides caching for action results to prevent redundant work and infinite loops.
# Cache key is computed from action name, arguments, and relevant context hash.
module ActionCache
  extend ActiveSupport::Concern

  included do
    attr_reader :action_cache, :cache_hits, :cache_misses
  end

  # Execute an action with caching
  # @param action_name [String, Symbol] The action to execute
  # @param arguments [Hash] Arguments for the action
  # @param context_hash [String] Hash of relevant context state
  # @yield Block that executes the actual action
  # @return [Object] The action result (cached or fresh)
  def execute_with_cache(action_name, arguments, context_hash)
    cache_key = compute_cache_key(action_name, arguments, context_hash)

    cached = fetch_from_cache(cache_key)
    if cached
      record_cache_hit(action_name, cache_key)
      return cached[:result]
    end

    result = yield
    store_in_cache(cache_key, action_name, arguments, result)
    record_cache_miss(action_name, cache_key)
    result
  end

  # Check if an action result is cached
  # @param action_name [String, Symbol] The action name
  # @param arguments [Hash] Arguments for the action
  # @param context_hash [String] Hash of relevant context state
  # @return [Boolean] True if cached
  def action_cached?(action_name, arguments, context_hash)
    cache_key = compute_cache_key(action_name, arguments, context_hash)
    action_cache_store.key?(cache_key)
  end

  # Clear the entire action cache
  def clear_action_cache!
    @action_cache = {}
    @cache_hits = 0
    @cache_misses = 0
  end

  # Clear cache entries for a specific action
  # @param action_name [String, Symbol] The action to clear
  def clear_cache_for(action_name)
    action_cache_store.delete_if { |_key, entry| entry[:action] == action_name.to_s }
  end

  # Get cache statistics
  # @return [Hash] Cache stats including hits, misses, and size
  def cache_stats
    {
      size: action_cache_store.size,
      hits: @cache_hits,
      misses: @cache_misses,
      hit_rate: calculate_hit_rate
    }
  end

  # Get all cached entries (for debugging)
  # @return [Array<Hash>] List of cache entries with metadata
  def cached_entries
    action_cache_store.map do |key, entry|
      {
        key: key,
        action: entry[:action],
        arguments: entry[:arguments],
        timestamp: entry[:timestamp],
        result_type: entry[:result].class.name
      }
    end
  end

  private

  def action_cache_store
    @action_cache ||= {}
  end

  def compute_cache_key(action_name, arguments, context_hash)
    # Arguments are always a Hash - normalize for consistent hashing
    normalized_args = arguments.sort.to_h
    content = "#{action_name}:#{normalized_args.to_json}:#{context_hash}"
    Digest::SHA256.hexdigest(content)
  end

  def fetch_from_cache(cache_key)
    action_cache_store[cache_key]
  end

  def store_in_cache(cache_key, action_name, arguments, result)
    action_cache_store[cache_key] = {
      action: action_name.to_s,
      arguments: arguments,
      result: result,
      timestamp: Time.now.utc
    }
  end

  def record_cache_hit(action_name, cache_key)
    @cache_hits += 1
  end

  def record_cache_miss(action_name, cache_key)
    @cache_misses += 1
  end

  def calculate_hit_rate
    total = @cache_hits + @cache_misses
    return 0.0 if total.zero?

    (@cache_hits.to_f / total * 100).round(2)
  end
end
