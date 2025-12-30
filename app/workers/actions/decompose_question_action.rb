# frozen_string_literal: true

module Actions
  # Action to decompose a research question into sub-questions.
  # Uses an LLM to break down complex questions into actionable pieces.
  class DecomposeQuestionAction < BaseAction
    class << self
      def description
        "Break down a complex question into smaller, more specific sub-questions"
      end

      def parameters
        {
          question: {
            type: :string,
            required: true,
            description: "The question to decompose"
          },
          max_questions: {
            type: :integer,
            required: false,
            description: "Maximum number of sub-questions to generate (default: 5)"
          },
          context: {
            type: :string,
            required: false,
            description: "Additional context to inform the decomposition"
          }
        }
      end

      def category
        :planning
      end
    end

    # Execute the question decomposition
    # @param question [String] The question to decompose
    # @param max_questions [Integer] Maximum sub-questions
    # @param context [String] Additional context
    # @return [Hash] Decomposition results with sub-questions
    def execute(question:, max_questions: 5, context: nil)
      return failure_result("Question cannot be empty") if question.strip.empty?

      # Check if this is already a leaf question (simple enough to answer directly)
      if leaf_question?(question)
        return success_result(
          original_question: question,
          is_leaf: true,
          sub_questions: [],
          summary: "Question is specific enough to answer directly"
        )
      end

      # Use the topic decomposition prompt
      sub_questions = llm_decompose(question, max_questions, context)

      # Record sub-questions to memory
      sub_questions.each do |sq|
        record_sub_question(sq)
      end

      success_result(
        original_question: question,
        is_leaf: false,
        sub_questions: sub_questions,
        count: sub_questions.size,
        findings: [{
          text: "Decomposed '#{question.truncate(50)}' into #{sub_questions.size} sub-questions",
          source: "decompose_question"
        }]
      )
    end

    
    def leaf_question?(question)
      # Simple heuristics for leaf questions
      words = question.split.size

      # Very short questions are likely leaves
      return true if words <= 5

      # Questions asking about specific things are likely leaves
      specific_patterns = [
        /where is .+ defined/i,
        /what (is|are) the (type|return|parameter)/i,
        /how many/i,
        /does .+ have/i,
        /is there a/i
      ]

      specific_patterns.any? { |p| question =~ p }
    end

    def llm_decompose(question, max_questions, additional_context)
      prompt = Research::TopicDecompositionPrompt.new

      # Build context for decomposition
      context = build_decomposition_context(additional_context)

      result = prompt.decompose(topic: question, context: context)
      response = result[:content]

      questions = response[:questions]
      questions.first(max_questions).map do |q|
        {
          id: SecureRandom.uuid,
          text: q[:question] || q[:text] || q.to_s,
          priority: q[:priority] || 1,
          is_leaf: q[:is_leaf] || false,
          rationale: q[:rationale],
          aspects: q[:aspects] || [],
          parent_question: question,
          status: "pending",
          created_at: Time.now.utc.iso8601
        }
      end
    end

    def build_decomposition_context(additional_context)
      context_hash = {}

      # Add codebase summary if we can generate one
      existing_questions = memory_store.get_section(:sub_questions)
      if existing_questions.any?
        context_hash[:previous_questions] = existing_questions.map { |q| q[:text] }
      end

      findings = memory_store.get_section(:findings)
      if findings.any?
        context_hash[:prior_knowledge] = findings.last(5).map { |f| f[:text] }.join("\n")
      end

      context_hash[:constraints] = additional_context if additional_context.present?
      context_hash
    end

    def record_sub_question(sub_question)
      memory_store.update_section(
        name: :sub_questions,
        content: sub_question,
        append: true
      )
    end
  end
end
