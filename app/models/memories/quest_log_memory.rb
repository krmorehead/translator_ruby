# frozen_string_literal: true

module Memories
  class QuestLogMemory < BaseMemory
    SECTION = MemoryKinds::QUEST_LOG

    def self.section_name = SECTION

    # Adds a quest entry with optional status
    # status can be: "open", "main", "current", "completed"
    def self.add(store, text:, status: "open")
      entries = store.get_section(SECTION) || []
      entries << normalize_entry({ text: text, status: status })
      store.set_section(SECTION, entries)
    end

    def self.set_main(store, text: nil, index: nil)
      update_flag(store, :main, text: text, index: index)
    end

    def self.set_current(store, text: nil, index: nil)
      update_flag(store, :current, text: text, index: index)
    end

    def self.entries(store)
      store.get_section(SECTION) || []
    end

    def self.default
      []
    end

    def self.update_flag(store, flag, text:, index:)
      raise ArgumentError, "provide text or index" if text.nil? && index.nil?

      entries = (store.get_section(SECTION) || []).map do |e|
        e = e.dup
        e[flag] = false
        e
      end

      target_idx = if index
                     index
                   else
                     entries.index { |e| (e[:text] || e["text"]) == text }
                   end
      raise ArgumentError, "quest not found" unless target_idx && entries[target_idx]

      entries[target_idx][flag] = true
      store.set_section(SECTION, entries)
    end
  end
end
