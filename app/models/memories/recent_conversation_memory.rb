# frozen_string_literal: true

module Memories
  class RecentConversationMemory < BaseMemory
    SECTION = MemoryKinds::RECENT_CONVERSATION
    def self.section_name = SECTION
  end
end
