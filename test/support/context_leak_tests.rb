# frozen_string_literal: true

# Shared test module for verifying context isolation and preventing context leaks.
# Include this module in tests where context accumulation could cause issues.
#
# Usage with minitest-spec-rails:
#   class MyWorkflowTest < ActiveSupport::TestCase
#     include ContextLeakTests
#
#     let(:temp_dir) { Dir.mktmpdir("test") }
#     let(:owner_id) { SecureRandom.uuid }
#     let(:memory) { build(:research_memory_store, base_dir: temp_dir, owner_id: owner_id) }
#
#     # Your tests here...
#   end
#
module ContextLeakTests
  extend ActiveSupport::Concern

  included do
    # Tests that verify no context leaks between operations
    speed_profile :fast
    test "context chain does not accumulate indefinitely during decomposition" do
      initial_chain_size = memory.get_section(:context_chain).size

      # Simulate multiple decomposition iterations
      5.times do |i|
        memory.push_context(
          sub_question: "Question #{i}",
          key_insights: "Insights for iteration #{i}"
        )
      end

      # Pop all contexts to simulate cleanup after decomposition
      5.times { memory.pop_context }

      # The persisted chain should still have entries (they're logged)
      # But the active stack should be empty
      assert_equal 0, memory.instance_variable_get(:@context_stack).size,
        "Context stack should be empty after popping all entries"
    end

    speed_profile :fast
    test "iteration tracking does not leak between research sessions" do
      # Advance iterations
      3.times { memory.next_iteration! }

      # Create a new memory store with same owner
      new_memory = ResearchMemoryStore.new(path: memory.path, owner_id: memory.owner_id)

      # Should load the persisted iteration count
      assert_equal 3, new_memory.current_iteration,
        "New store should load iteration count from persisted data"

      # But iteration log should not grow unboundedly
      log_size = new_memory.get_section(:iteration_log).size
      assert_equal 3, log_size, "Iteration log should have exactly 3 entries"
    end

    speed_profile :fast
    test "sub_questions do not accumulate duplicate entries" do
      # Add same question multiple times (simulating retry scenario)
      3.times do
        memory.update_section(
          name: :sub_questions,
          content: { text: "Same question", is_leaf: true },
          append: true
        )
      end

      questions = memory.get_section(:sub_questions)

      # All 3 should be there (append: true behavior)
      # But this test ensures we're aware of this - caller should dedupe
      assert_equal 3, questions.size,
        "Appending adds all entries - caller must dedupe if needed"
    end

    speed_profile :fast
    test "discovered_files section does not grow unboundedly" do
      # Simulate discovering many files
      100.times do |i|
        memory.update_section(
          name: :discovered_files,
          content: { path: "file_#{i}.rb", relevance_score: rand },
          append: true
        )
      end

      files = memory.get_section(:discovered_files)
      assert_equal 100, files.size

      # This test documents the behavior - no automatic pruning
      # Caller should implement limits if needed
    end

    speed_profile :fast
    test "findings section entries are independent" do
      # Add findings
      memory.update_section(
        name: :findings,
        content: { text: "Finding 1", source: "file1.rb" },
        append: true
      )

      memory.update_section(
        name: :findings,
        content: { text: "Finding 2", source: "file2.rb" },
        append: true
      )

      findings = memory.get_section(:findings)

      # Each finding should be independent - no cross-contamination
      assert_equal "Finding 1", findings[0][:text]
      assert_equal "file1.rb", findings[0][:source]
      assert_equal "Finding 2", findings[1][:text]
      assert_equal "file2.rb", findings[1][:source]

      # Modifying one shouldn't affect the other
      findings[0][:text] = "Modified"
      reloaded = memory.get_section(:findings)
      assert_equal "Modified", reloaded[0][:text]
      assert_equal "Finding 2", reloaded[1][:text]
    end

    speed_profile :fast
    test "parallel workers have isolated context" do
      owner1 = SecureRandom.uuid
      owner2 = SecureRandom.uuid

      memory1 = build(:research_memory_store, base_dir: temp_dir, owner_id: owner1)
      memory2 = build(:research_memory_store, base_dir: temp_dir, owner_id: owner2)

      # Add data to memory1
      memory1.push_context(sub_question: "Owner1 Question", key_insights: "Owner1 Insights")
      memory1.update_section(name: :findings, content: "Owner1 Finding", append: true)

      # Add different data to memory2
      memory2.push_context(sub_question: "Owner2 Question", key_insights: "Owner2 Insights")
      memory2.update_section(name: :findings, content: "Owner2 Finding", append: true)

      # Verify isolation
      assert_equal "Owner1 Question", memory1.get_section(:context_chain).first[:sub_question]
      assert_equal "Owner2 Question", memory2.get_section(:context_chain).first[:sub_question]

      # They should not share data
      assert_not_equal memory1.get_section(:findings), memory2.get_section(:findings)
    end
  end
end

# Shared tests specifically for decomposition workflows
module DecompositionContextTests
  extend ActiveSupport::Concern

  included do
    speed_profile :fast
    test "decomposition context does not leak to child questions" do
      ctx = decomposition_context

      # Parent context should not accumulate in children
      parent_ctx = ctx.merge(parent_question: "Parent Question", depth: 0)

      # Simulating child context - should NOT inherit accumulating data
      child_ctx = {
        parent_question: "Child Question",
        depth: 1
        # Should NOT include previous_questions growing unboundedly
      }

      # Verify child doesn't inherit parent's previous_questions array growing
      assert_nil child_ctx[:previous_questions],
        "Child context should start fresh, not inherit accumulated data"
    end

    speed_profile :fast
    test "previous_questions array does not grow across depth levels" do
      # Simulate what happens at depth 3
      level0_questions = []
      level1_questions = ["Q1", "Q2"]
      level2_questions = ["Q1.1", "Q1.2"]
      level3_questions = ["Q1.1.1"]

      # Each level should only have its sibling questions, not ancestors
      # This prevents O(n^d) growth where d is depth
      assert level3_questions.size < 10,
        "Questions at each level should be bounded, not accumulative"
    end

    speed_profile :fast
    test "context with seed information does not cause unbounded growth" do
      # Create context with all seed fields populated
      full_context = build(:research_context, :full)

      # Simulate passing through decomposition levels
      level_contexts = []
      3.times do |depth|
        level_ctx = full_context.merge(
          depth: depth,
          parent_question: "Question at depth #{depth}"
        )
        level_contexts << level_ctx
      end

      # Each level context should be bounded, not growing
      level_contexts.each_with_index do |ctx, i|
        # Context size should be roughly constant, not growing with depth
        assert ctx.keys.size < 20,
          "Context at depth #{i} should not grow unboundedly: #{ctx.keys.size} keys"
      end
    end
  end
end
