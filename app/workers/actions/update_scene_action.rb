# frozen_string_literal: true

module Actions
  # Action to update the current scene description or state.
  class UpdateSceneAction < BaseAction
    def execute(description:, changes: [])
      # Get current scene
      current_scene = memory_store.get_section(MemoryKinds::CURRENT_SCENE)

      # Build updated scene
      new_scene = if current_scene.is_a?(String)
        "#{current_scene}\n\n#{description}"
      else
        description
      end

      # Store the updated scene
      memory_store.update_section(
        name: MemoryKinds::CURRENT_SCENE,
        content: new_scene
      )

      # Record changes if any
      if changes.any?
        changes.each do |change|
          memory_store.update_section(
            name: MemoryKinds::GENERAL_KNOWLEDGE,
            content: { text: change, type: "scene_change", timestamp: Time.now.utc.iso8601 },
            append: true
          )
        end
      end

      success_result(
        result: "Scene updated: #{description.truncate(100)}",
        summary: "Scene description updated",
        metadata: { description: description, changes: changes }
      )
    end
  end
end

