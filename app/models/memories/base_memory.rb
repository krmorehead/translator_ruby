# frozen_string_literal: true

module Memories
  class BaseMemory
    def self.section_name
      raise NotImplementedError, "#{name} must implement .section_name"
    end

    # Default summarization: concatenate text entries; subclasses may override to call LLMs.
    def self.summarize(store:)
      entries = store.get_section(section_name) || []
      texts = Array(entries).map { |e| e.is_a?(Hash) ? (e[:text] || e["text"]) : e }.compact
      {
        section: section_name,
        summary: texts.join(" ").strip
      }
    end

    # Relative importance for compression; subclasses may override.
    def self.weight
      raise NotImplementedError, "#{name} must implement .weight"
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
