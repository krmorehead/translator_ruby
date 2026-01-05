# frozen_string_literal: true

# Simple in-memory key-value cache that mimics Redis interface.
# Used for session data, approval requests, and execution state.
# Thread-safe via Mutex.
#
# This is a CACHE (key-value store), not a domain model.
# For agent memory domain models, see app/models/memory_store.rb
class SessionCache
  def initialize
    @data = {}
    @sets = {}
    @sorted_sets = {}
    @mutex = Mutex.new
  end

  # Get a value
  def get(key)
    @mutex.synchronize { @data[key] }
  end

  # Set a value with optional expiry (expiry is ignored in memory store)
  def set(key, value)
    @mutex.synchronize { @data[key] = value }
  end

  # Set with expiry (expiry ignored - just stores the value)
  def setex(key, _ttl, value)
    set(key, value)
  end

  # Delete a key
  def del(key)
    @mutex.synchronize do
      if @data.key?(key)
        @data.delete(key)
        1
      else
        0
      end
    end
  end

  # Check if key exists
  def exists?(key)
    @mutex.synchronize { @data.key?(key) }
  end

  # Set expiry on a key (no-op in memory store)
  def expire(_key, _seconds)
    true
  end

  # Add to a set
  def sadd(key, member)
    @mutex.synchronize do
      @sets[key] ||= Set.new
      @sets[key].add(member)
    end
  end

  # Remove from a set
  def srem(key, member)
    @mutex.synchronize do
      return 0 unless @sets[key]
      return 0 unless @sets[key].include?(member)

      @sets[key].delete(member)
      1
    end
  end

  # Get all members of a set
  def smembers(key)
    @mutex.synchronize do
      (@sets[key] || Set.new).to_a
    end
  end

  # Ping (always succeeds)
  def ping
    "PONG"
  end

  # Sorted set: add member with score
  def zadd(key, score, member)
    @mutex.synchronize do
      @sorted_sets[key] ||= {}
      @sorted_sets[key][member] = score
      1
    end
  end

  # Sorted set: remove member
  def zrem(key, member)
    @mutex.synchronize do
      return 0 unless @sorted_sets[key]

      @sorted_sets[key].delete(member) ? 1 : 0
    end
  end

  # Sorted set: get range by index (ascending order)
  def zrange(key, start_idx, stop_idx)
    @mutex.synchronize do
      return [] unless @sorted_sets[key]

      sorted = @sorted_sets[key].sort_by { |_member, score| score }.map(&:first)
      stop_idx = sorted.size - 1 if stop_idx == -1
      sorted[start_idx..stop_idx] || []
    end
  end

  # Sorted set: get range by index (descending order)
  def zrevrange(key, start_idx, stop_idx)
    @mutex.synchronize do
      return [] unless @sorted_sets[key]

      sorted = @sorted_sets[key].sort_by { |_member, score| -score }.map(&:first)
      stop_idx = sorted.size - 1 if stop_idx == -1
      sorted[start_idx..stop_idx] || []
    end
  end

  # Clear all data (useful for testing)
  def flushall
    @mutex.synchronize do
      @data.clear
      @sets.clear
      @sorted_sets.clear
    end
  end

  # Singleton instance for global access
  def self.instance
    @instance ||= new
  end
end

