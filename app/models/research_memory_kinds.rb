# frozen_string_literal: true

# Defines canonical memory section names for research workers.
module ResearchMemoryKinds
  RESEARCH_GOAL = "research_goal".freeze
  SUB_QUESTIONS = "sub_questions".freeze
  DISCOVERED_FILES = "discovered_files".freeze
  FINDINGS = "findings".freeze
  CONTEXT_CHAIN = "context_chain".freeze
  ITERATION_LOG = "iteration_log".freeze

  ALL = [
    RESEARCH_GOAL,
    SUB_QUESTIONS,
    DISCOVERED_FILES,
    FINDINGS,
    CONTEXT_CHAIN,
    ITERATION_LOG
  ].freeze
end

