# frozen_string_literal: true

module Actions
  # Action that updates the current scene description
  class UpdateSceneAction < BaseAction
    def execute(description:, changes: [])
      # Update scene in memory
      scene_data = {
        description: description,
        changes: changes,
        updated_at: Time.now.utc.iso8601
      }
      
      memory_store.set_section(MemoryKinds::CURRENT_SCENE, scene_data)
      
      summary = "Updated scene: #{description.truncate(50)}"
      success_result(scene_data, summary: summary)
    end
  end
end
