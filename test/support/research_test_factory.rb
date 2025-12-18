# frozen_string_literal: true

# Factory methods for creating research test objects
# Use with let() style memoization in tests
module ResearchTestFactory
  FIXTURE_PATH = Rails.root.join("test", "fixtures", "example_codebase").to_s

  # Create a research workflow with sensible defaults
  # @param goal [String] Research goal
  # @param owner_id [String] Owner ID (auto-generated if nil)
  # @param max_depth [Integer] Maximum decomposition depth
  # @param output_modes [Array<Symbol>] Output modes
  # @param research_path [String] Path to research
  # @return [ResearchWorkflow]
  def build_workflow(
    goal: "How does Calculator work?",
    owner_id: nil,
    max_depth: 1,
    output_modes: [:report],
    research_path: FIXTURE_PATH
  )
    ResearchWorkflow.new(
      goal: goal,
      owner_id: owner_id || SecureRandom.uuid,
      research_path: research_path,
      max_depth: max_depth,
      output_modes: output_modes
    )
  end

  # Create a codebase researcher worker
  # @param goal [String] Research goal
  # @param path [String] Path to research
  # @param max_depth [Integer] Maximum decomposition depth
  # @param output_modes [Array<Symbol>] Output modes
  # @return [CodebaseResearcher]
  def build_researcher(
    goal: "How does Calculator work?",
    path: FIXTURE_PATH,
    max_depth: 1,
    output_modes: [:report]
  )
    CodebaseResearcher.new(
      goal: goal,
      path: path,
      max_depth: max_depth,
      output_modes: output_modes
    )
  end

  # Create a research context with sample data
  # @param research_goal [String] The research goal
  # @param with_findings [Boolean] Include sample findings
  # @param with_sub_questions [Boolean] Include sample sub-questions
  # @return [Contexts::ResearchContext]
  def build_research_context(
    research_goal: "How does Calculator work?",
    with_findings: false,
    with_sub_questions: false
  )
    context = Contexts::ResearchContext.new(research_goal: research_goal)

    if with_sub_questions
      context.add_sub_question(
        question: "What methods does Calculator expose?",
        priority: 1
      )
      context.add_sub_question(
        question: "How does Formatter use Calculator?",
        priority: 2
      )
    end

    if with_findings
      context.add_finding(
        finding: "Calculator has add, subtract, multiply, divide methods",
        file_path: "lib/calculator.rb",
        sub_question: "What methods does Calculator expose?",
        confidence: 0.9
      )
      context.add_finding(
        finding: "Formatter formats Calculator output as strings",
        file_path: "lib/formatter.rb",
        sub_question: "How does Formatter use Calculator?",
        confidence: 0.85
      )
    end

    context
  end

  # Create a research memory store
  # @param owner_id [String] Owner ID
  # @param temp_path [String] Temporary path for persistence
  # @return [ResearchMemoryStore]
  def build_memory_store(owner_id: nil, temp_path: nil)
    owner = owner_id || SecureRandom.uuid
    path = temp_path || Rails.root.join("tmp", "test_memory_#{owner}.json").to_s
    ResearchMemoryStore.new(path: path, owner_id: owner)
  end

  # Memoization helper for let()-style usage
  # @example
  #   include ResearchTestFactory
  #
  #   def workflow
  #     @workflow ||= build_workflow(goal: "Test goal")
  #   end
  #
  #   def context
  #     @context ||= build_research_context(with_findings: true)
  #   end
end

