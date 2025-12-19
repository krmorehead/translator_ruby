# frozen_string_literal: true

# Defines canonical memory section names for research workers.
module ResearchMemoryKinds
  RESEARCH_GOAL = "research_goal".freeze
  SUB_QUESTIONS = "sub_questions".freeze
  DISCOVERED_FILES = "discovered_files".freeze
  FINDINGS = "findings".freeze
  CONTEXT_CHAIN = "context_chain".freeze
  ITERATION_LOG = "iteration_log".freeze
  STATE_TRANSITIONS = "state_transitions".freeze
  WORKFLOW_OUTPUTS = "workflow_outputs".freeze
  DOCUMENTATION_CACHE = "documentation_cache".freeze
  ACTION_HISTORY = "action_history".freeze

  ALL = [
    RESEARCH_GOAL,
    SUB_QUESTIONS,
    DISCOVERED_FILES,
    FINDINGS,
    CONTEXT_CHAIN,
    ITERATION_LOG,
    STATE_TRANSITIONS,
    WORKFLOW_OUTPUTS,
    DOCUMENTATION_CACHE,
    ACTION_HISTORY
  ].freeze
end

