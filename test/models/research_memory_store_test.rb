require "test_helper"

class ResearchMemoryStoreTest < ActiveSupport::TestCase
  include ContextLeakTests

  # Use let for lazy-evaluated, memoized test fixtures
  let(:temp_dir) do
    dir = Rails.root.join("tmp", "research_memory_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(dir)
    dir
  end

  let(:owner_id) { SecureRandom.uuid }
  let(:store_path) { File.join(temp_dir, owner_id, "research_memory.json") }

  # Required by ContextLeakTests - uses factory
  let(:memory) { build(:research_memory_store, owner_id: owner_id) }

  def teardown
    FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
  end
  speed_profile :fast
  test "creates with default sections" do
    store = ResearchMemoryStore.new(path: store_path, owner_id: owner_id)

    assert_kind_of String, store.id
    assert_includes store.list_sections, :research_goal
    assert_includes store.list_sections, :sub_questions
    assert_includes store.list_sections, :discovered_files
    assert_includes store.list_sections, :findings
    assert_includes store.list_sections, :context_chain
    assert_includes store.list_sections, :iteration_log
  end

  speed_profile :fast
  test "stores have unique IDs" do
    store1 = ResearchMemoryStore.new(path: File.join(temp_dir, "store1.json"), owner_id: owner_id)
    store2 = ResearchMemoryStore.new(path: File.join(temp_dir, "store2.json"), owner_id: SecureRandom.uuid)
    
    assert_not_equal store1.id, store2.id
  end

  speed_profile :fast
  test "find_by_path loads existing store" do
    # Create and persist a store
    store1 = ResearchMemoryStore.new(path: store_path, owner_id: owner_id)
    store1.set_section(:research_goal, [{ text: "Test goal", timestamp: Time.now.utc.iso8601 }])

    # Load it using find_by_path
    store2 = ResearchMemoryStore.find_by_path(store_path)

    assert_not_nil store2
    goal = store2.get_section(:research_goal).first
    assert_equal "Test goal", goal[:text]
  end

  speed_profile :fast
  test "find_by_owner returns nil for non-existent owner" do
    store = ResearchMemoryStore.find_by_owner("nonexistent-#{SecureRandom.uuid}", base_path: temp_dir)
    assert_nil store
  end

  speed_profile :fast
  test "list_owners returns all session IDs" do
    # Create multiple stores using factories
    other_owner1 = SecureRandom.uuid
    other_owner2 = SecureRandom.uuid

    store1 = build(:research_memory_store, owner_id: other_owner1)
    store1.set_section(:research_goal, [{ text: "Goal 1" }])
    store1.save!

    store2 = build(:research_memory_store, owner_id: other_owner2)
    store2.set_section(:research_goal, [{ text: "Goal 2" }])
    store2.save!

    owners = ResearchMemoryStore.list_owners

    assert_includes owners, other_owner1
    assert_includes owners, other_owner2
  end

  speed_profile :fast
  test "push_context and pop_context work correctly" do
    context1 = { sub_question: "How does X work?", key_insights: "X uses pattern Y" }
    context2 = { sub_question: "Where is Z defined?", key_insights: "Z is in file.rb" }

    memory.push_context(context1)
    memory.push_context(context2)

    assert_equal 2, memory.get_section(:context_chain).size

    popped = memory.pop_context
    assert_equal "Where is Z defined?", popped[:sub_question]

    popped = memory.pop_context
    assert_equal "How does X work?", popped[:sub_question]

    assert_nil memory.pop_context
  end

  speed_profile :fast
  test "chain_for retrieves context for specific sub-question" do
    memory.push_context({ sub_question: "Q1", key_insights: "Insight 1" })
    memory.push_context({ sub_question: "Q2", key_insights: "Insight 2" })
    memory.push_context({ sub_question: "Q1", key_insights: "Insight 3" })

    chain = memory.chain_for("Q1")
    assert_equal 2, chain.size
    assert chain.all? { |e| e[:sub_question] == "Q1" }
  end

  speed_profile :fast
  test "iteration tracking works correctly" do
    assert_equal 0, memory.current_iteration

    memory.next_iteration!
    assert_equal 1, memory.current_iteration

    memory.next_iteration!
    assert_equal 2, memory.current_iteration

    # Check iteration log
    log = memory.get_section(:iteration_log)
    assert_equal 2, log.size
    assert_equal 1, log.first[:iteration]
    assert_equal 2, log.last[:iteration]
  end

  speed_profile :fast
  test "summarize_findings produces summary" do
    memory.set_section(:research_goal, [{ text: "Research topic" }])
    memory.update_section(name: :sub_questions, content: { text: "Q1" })
    memory.update_section(name: :sub_questions, content: { text: "Q2" })
    memory.update_section(name: :discovered_files, content: { path: "file1.rb" })
    memory.update_section(name: :findings, content: { text: "Finding 1" })
    memory.update_section(name: :findings, content: { text: "Finding 2" })

    summary = memory.summarize_findings

    assert_equal "Research topic", summary[:goal]
    assert_equal 2, summary[:sub_question_count]
    assert_equal 1, summary[:discovered_file_count]
    assert_equal 2, summary[:finding_count]
    assert_includes summary[:findings_summary], "Finding 1"
    assert_includes summary[:findings_summary], "Finding 2"
  end

  speed_profile :fast
  test "persistence to file" do
    store1 = ResearchMemoryStore.new(path: store_path, owner_id: owner_id)
    store1.set_section(:research_goal, [{ text: "Persistent goal", timestamp: Time.now.utc.iso8601 }])
    store1.next_iteration!

    # Load from file
    store2 = ResearchMemoryStore.new(path: store_path, owner_id: owner_id)

    goal = store2.get_section(:research_goal).first
    assert_equal "Persistent goal", goal[:text]
    assert_equal 1, store2.current_iteration
  end

  speed_profile :fast
  test "parallel stores with different owner_ids are isolated" do
    # Use factories for parallel stores
    parallel_owner1 = SecureRandom.uuid
    parallel_owner2 = SecureRandom.uuid

    store1 = build(:research_memory_store, owner_id: parallel_owner1)
    store2 = build(:research_memory_store, owner_id: parallel_owner2)

    store1.set_section(:research_goal, [{ text: "Goal for owner 1" }])
    store2.set_section(:research_goal, [{ text: "Goal for owner 2" }])

    # Verify isolation
    goal1 = store1.get_section(:research_goal).first[:text]
    goal2 = store2.get_section(:research_goal).first[:text]

    assert_equal "Goal for owner 1", goal1
    assert_equal "Goal for owner 2", goal2
    assert_not_equal goal1, goal2
  end

  speed_profile :fast
  test "update_section appends by default" do
    memory.update_section(name: :findings, content: { text: "Finding 1" })
    memory.update_section(name: :findings, content: { text: "Finding 2" })

    findings = memory.get_section(:findings)
    assert_equal 2, findings.size
  end

  speed_profile :fast
  test "update_section replaces when append is false" do
    memory.update_section(name: :findings, content: { text: "Finding 1" })
    memory.update_section(name: :findings, content: { text: "Finding 2" }, append: false)

    findings = memory.get_section(:findings)
    assert_equal 1, findings.size
    assert_equal "Finding 2", findings.first[:text]
  end

  # Test factory traits
  speed_profile :fast
  test "factory with_goal trait works" do
    store = build(:research_memory_store, :with_goal)
    goal = store.get_section(:research_goal).first
    assert_equal "Test research goal", goal[:text]
  end

  speed_profile :fast
  test "factory with_context_chain trait works" do
    store = build(:research_memory_store, :with_context_chain)
    chain = store.get_section(:context_chain)
    assert_equal 2, chain.size
  end

  speed_profile :fast
  test "factory full trait creates complete store" do
    store = build(:research_memory_store, :full)

    assert store.get_section(:research_goal).any?
    assert store.get_section(:sub_questions).any?
    assert store.get_section(:discovered_files).any?
    assert store.get_section(:context_chain).any?
  end
end

