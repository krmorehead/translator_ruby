# frozen_string_literal: true

require "time"
require_relative "../memory_kinds"

module Memories
  class BaseMemory
    def self.section_name
      raise NotImplementedError, "#{name} must implement .section_name"
    end

    def self.default
      []
    end

    # Normalize any entry to a hash with a timestamp
    def self.normalize_entry(content)
      entry =
        if content.is_a?(Hash)
          content.dup
        else
          { text: content }
        end
      entry[:timestamp] ||= Time.now.utc.iso8601
      entry
    end
  end
end

