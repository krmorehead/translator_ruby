require "test_helper"

class ResearchMemoryStoreTest < ActiveSupport::TestCase
  include ContextLeakTests

  # Use let for lazy-evaluated, memoized test fixtures
  let(:temp_dir) do
    dir = Rails.root.join("tmp", "research_memory_test_#{Process.pid}_#{Thread.current.object_id}").to_s
    FileUtils.mkdir_p(dir)
    dir
  end

  let(:owner_id) { "test-owner-research-memory" }
  let(:workflow_id) { "test-workflow-#{Process.pid}-#{Thread.current.object_id}" }
  let(:parent_id) { "test-parent-research-memory" }
  let(:workflow_name) { "test_research_workflow" }
  let(:store_path) { File.join(temp_dir, owner_id, "research_memory.json") }

  # Required by ContextLeakTests - uses factory
  let(:memory) { build(:research_memory_store, owner_id: owner_id, workflow_id: workflow_id, parent_id: parent_id) }

  def teardown
    FileUtils.rm_rf(temp_dir) if temp_dir && File.exist?(temp_dir)
  end
  speed_profile :fast
  test "creates with default sections" do
    store = ResearchMemoryStore.new(
      workflow_id: workflow_id,
      workflow_name: workflow_name,
      parent_id: parent_id,
      owner_id: owner_id
    )

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
    store1 = ResearchMemoryStore.new(
      workflow_id: "store1-#{workflow_id}",
      workflow_name: workflow_name,
      parent_id: parent_id,
      owner_id: owner_id
    )
    store2 = ResearchMemoryStore.new(
      workflow_id: "store2-#{workflow_id}",
      workflow_name: workflow_name,
      parent_id: "parent2",
      owner_id: "owner2"
    )
    
    assert_not_equal store1.id, store2.id
  end

  # REMOVED: find_by_path is not part of the new OOP design
  # ResearchMemoryStore now uses from_h for deserialization
  # speed_profile :fast
  # test "find_by_path loads existing store" do
  #   ...
  # end

  # REMOVED: find_by_owner is not part of the new OOP design  
  # speed_profile :fast
  # test "find_by_owner returns nil for non-existent owner" do
  #   ...
  # end

  # REMOVED: list_owners is not part of the new OOP design
  # speed_profile :fast
  # test "list_owners returns all session IDs" do
  #   ...
  # end

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
    
    # Create Finding objects, not hashes
    finding1 = WorkflowMemories::Finding.new(
      id: SecureRandom.uuid,
      text: "Finding 1",
      relevance: "direct",
      confidence: 0.9,
      file_path: "file1.rb",
      pass_number: 1
    )
    finding2 = WorkflowMemories::Finding.new(
      id: SecureRandom.uuid,
      text: "Finding 2",
      relevance: "direct",
      confidence: 0.8,
      file_path: "file1.rb",
      pass_number: 1
    )
    memory.update_section(name: :findings, content: finding1)
    memory.update_section(name: :findings, content: finding2)

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
    store1 = ResearchMemoryStore.new(
      workflow_id: workflow_id,
      workflow_name: workflow_name,
      parent_id: parent_id,
      owner_id: owner_id
    )
    store1.set_section(:research_goal, [{ text: "Persistent goal", timestamp: Time.now.utc.iso8601 }])
    store1.next_iteration!

    # Load from file using from_h (OOP deserialization pattern)
    saved_data = JSON.parse(File.read(store1.path), symbolize_names: true)
    store2 = ResearchMemoryStore.from_h(saved_data)

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
    finding1 = WorkflowMemories::Finding.new(
      id: SecureRandom.uuid,
      text: "Finding 1",
      relevance: "direct",
      confidence: 0.9,
      file_path: "test.rb",
      pass_number: 1
    )
    finding2 = WorkflowMemories::Finding.new(
      id: SecureRandom.uuid,
      text: "Finding 2",
      relevance: "direct",
      confidence: 0.8,
      file_path: "test.rb",
      pass_number: 1
    )
    memory.update_section(name: :findings, content: finding1)
    memory.update_section(name: :findings, content: finding2)

    findings = memory.get_section(:findings)
    assert_equal 2, findings.size
  end

  speed_profile :fast
  test "update_section replaces when append is false" do
    finding1 = WorkflowMemories::Finding.new(
      id: SecureRandom.uuid,
      text: "Finding 1",
      relevance: "direct",
      confidence: 0.9,
      file_path: "test.rb",
      pass_number: 1
    )
    finding2 = WorkflowMemories::Finding.new(
      id: SecureRandom.uuid,
      text: "Finding 2",
      relevance: "direct",
      confidence: 0.8,
      file_path: "test.rb",
      pass_number: 1
    )
    memory.update_section(name: :findings, content: finding1)
    memory.update_section(name: :findings, content: finding2, append: false)

    findings = memory.get_section(:findings)
    assert_equal 1, findings.size
    assert_equal "Finding 2", findings.first.text
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

