# frozen_string_literal: true

module Actions
  # Action to update quest status or add a new quest.
  class AdvanceQuestAction < BaseAction
    VALID_STATUSES = %w[active completed failed].freeze

    def execute(quest_name:, status:, notes: nil)
      status = status.to_s.downcase
      unless VALID_STATUSES.include?(status)
        return failure_result(error: "Invalid status: #{status}. Use: #{VALID_STATUSES.join(', ')}")
      end

      quest_entry = {
        text: quest_name,
        status: status,
        notes: notes,
        updated_at: Time.now.utc.iso8601
      }

      memory_store.update_section(
        name: MemoryKinds::QUEST_LOG,
        content: quest_entry,
        append: true
      )

      result_text = case status
      when "active" then "Quest started: #{quest_name}"
      when "completed" then "Quest completed: #{quest_name}!"
      when "failed" then "Quest failed: #{quest_name}"
      end

      success_result(
        result: result_text,
        summary: result_text,
        findings: [{ text: result_text, source: "quest" }],
        metadata: quest_entry
      )
    end
  end
end

