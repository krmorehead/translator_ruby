# frozen_string_literal: true

# State machine DSL for workers.
# Provides runtime-enforced state transitions with optional guards and hooks.
#
# @example Basic usage
#   class MyWorker
#     include StateMachine
#
#     initial_state :pending
#
#     state :pending
#     state :running
#     state :complete
#     state :failed
#
#     transition from: :pending, to: :running, on: :start
#     transition from: :running, to: :complete, on: :finish
#     transition from: [:pending, :running], to: :failed, on: :fail
#   end
#
# @example With guards
#   transition from: :pending, to: :running, on: :start do |payload|
#     payload[:goal].present?
#   end
#
# @example With hooks
#   on_enter :running do
#     log_started
#   end
#
#   on_exit :running do
#     log_finished
#   end
#
module StateMachine
  extend ActiveSupport::Concern

  # Raised when an invalid state transition is attempted
  class InvalidTransition < StandardError; end

  # Raised when an unknown event is triggered
  class UnknownEvent < StandardError; end

  # Raised when trying to transition to an unknown state
  class UnknownState < StandardError; end

  included do
    # Use instance_accessor: false to prevent instance methods from being generated
    # We manage state per-instance, not per-class
    class_attribute :_states, default: {}, instance_accessor: false, instance_writer: false
    class_attribute :_transitions, default: {}, instance_accessor: false, instance_writer: false
    class_attribute :_initial_state, default: nil, instance_accessor: false, instance_writer: false
    class_attribute :_enter_hooks, default: {}, instance_accessor: false, instance_writer: false
    class_attribute :_exit_hooks, default: {}, instance_accessor: false, instance_writer: false
    class_attribute :_transition_hooks, default: [], instance_accessor: false, instance_writer: false
  end

  class_methods do
    # Called when a class inherits from a class with StateMachine
    # Creates deep copies of parent's state machine attributes for the child class
    # This ensures subclasses inherit parent states/transitions but can override them
    def inherited(subclass)
      super
      # Deep dup parent's state machine definitions so subclass can modify without affecting parent
      subclass._states = deep_dup_hash(_states)
      subclass._transitions = deep_dup_hash(_transitions)
      subclass._initial_state = _initial_state
      subclass._enter_hooks = deep_dup_hash(_enter_hooks)
      subclass._exit_hooks = deep_dup_hash(_exit_hooks)
      subclass._transition_hooks = _transition_hooks.dup
    end

    
    def deep_dup_hash(hash)
      return {} if hash.nil?

      hash.each_with_object({}) do |(k, v), result|
        result[k] = v.is_a?(Hash) ? deep_dup_hash(v) : v.dup rescue v
      end
    end

    public

    # Define a state with optional metadata
    # @param name [Symbol] The state name
    # @param options [Hash] Optional metadata (e.g., phase: :setup)
    def state(name, **options)
      # Deep dup to avoid mutating parent class attributes
      self._states = _states.dup
      _states[name.to_sym] = options.merge(name: name.to_sym)
    end

    # Define a transition between states
    # @param from [Symbol, Array<Symbol>] Source state(s)
    # @param to [Symbol] Target state
    # @param on [Symbol] Event name that triggers this transition
    # @yield Optional guard block that must return truthy for transition to proceed
    def transition(from:, to:, on:, &guard)
      self._transitions = _transitions.deep_dup
      event_key = on.to_sym
      from_states = Array(from).map(&:to_sym)
      new_route = { from: from_states, to: to.to_sym, guard: guard }

      if _transitions[event_key]
        existing = _transitions[event_key]
        existing_routes = existing[:routes] || [{ from: existing[:from], to: existing[:to], guard: existing[:guard] }]

        # Remove any existing routes that have overlapping source states
        # This allows subclasses to override parent transitions
        filtered_routes = existing_routes.reject do |route|
          (route[:from] & from_states).any?
        end

        # Add the new route
        all_routes = filtered_routes + [new_route]
        all_from_states = all_routes.flat_map { |r| r[:from] }.uniq

        _transitions[event_key] = {
          from: all_from_states,
          to: to.to_sym,
          guard: guard,
          routes: all_routes
        }
      else
        _transitions[event_key] = {
          from: from_states,
          to: to.to_sym,
          guard: guard,
          routes: [new_route]
        }
      end
    end

    # Set the initial state for new instances
    # @param name [Symbol] The initial state name
    def initial_state(name)
      self._initial_state = name.to_sym
    end

    # Define a hook to run when entering a state
    # @param state [Symbol] The state to hook
    # @yield Block to execute when entering the state
    def on_enter(state, &block)
      self._enter_hooks = _enter_hooks.dup
      _enter_hooks[state.to_sym] = block
    end

    # Define a hook to run when exiting a state
    # @param state [Symbol] The state to hook
    # @yield Block to execute when exiting the state
    def on_exit(state, &block)
      self._exit_hooks = _exit_hooks.dup
      _exit_hooks[state.to_sym] = block
    end

    # Define a hook to run on any transition
    # @yield Block to execute with (from_state, to_state, event, payload)
    def on_transition(&block)
      self._transition_hooks = _transition_hooks.dup
      _transition_hooks << block
    end

    # Get all defined states
    def states
      _states.keys
    end

    # Get all defined events
    def events
      _transitions.keys
    end

    # Check if a state is defined
    def state?(name)
      _states.key?(name.to_sym)
    end

    # Check if an event is defined
    def event?(name)
      _transitions.key?(name.to_sym)
    end

    # Get transitions that can be triggered from a given state
    def transitions_from(state)
      _transitions.select { |_, t| t[:from].include?(state.to_sym) }
    end
  end

  # Initialize state machine state
  def initialize_state_machine
    @current_state = self.class._initial_state
    @state_history = []
    @state_entered_at = Time.now.utc
  end

  # Get the current state
  # @return [Symbol] The current state
  def current_state
    @current_state ||= self.class._initial_state
  end

  # Get the state history
  # @return [Array<Hash>] History of state transitions
  def state_history
    @state_history ||= []
  end

  # Get metadata for the current state
  # @return [Hash] State metadata
  def current_state_info
    self.class._states[current_state] || {}
  end

  # Get the current phase (if states define phases)
  # @return [Symbol, nil] The current phase or nil
  def current_phase
    current_state_info[:phase]
  end

  # Check if in a specific state
  # @param state [Symbol] The state to check
  # @return [Boolean]
  def in_state?(state)
    current_state == state.to_sym
  end

  # Check if a transition can be triggered
  # @param event [Symbol] The event to check
  # @return [Boolean]
  def can_trigger?(event)
    transition = self.class._transitions[event.to_sym]
    return false unless transition
    return false unless transition[:from].include?(current_state)

    # Check guard if present
    if transition[:guard]
      begin
        instance_exec({}, &transition[:guard])
      rescue StandardError
        false
      end
    else
      true
    end
  end

  # Get available events from current state
  # @return [Array<Symbol>] Events that can be triggered
  def available_events
    self.class._transitions.select do |event, transition|
      transition[:from].include?(current_state) && can_trigger?(event)
    end.keys
  end

  # Trigger a state transition
  # @param event [Symbol] The event to trigger
  # @param payload [Hash] Optional payload passed to guards and hooks
  # @return [Symbol] The new state
  # @raise [UnknownEvent] If the event is not defined
  # @raise [InvalidTransition] If the transition is not valid from current state
  def trigger(event, **payload)
    event = event.to_sym
    transition = self.class._transitions[event]

    raise UnknownEvent, "Unknown event: #{event}" unless transition

    unless transition[:from].include?(current_state)
      raise InvalidTransition,
            "Cannot trigger '#{event}' from state '#{current_state}'. " \
            "Valid source states: #{transition[:from].join(', ')}"
    end

    # Find the matching route for the current state
    route = find_route(transition, current_state)

    # Check guard
    if route[:guard] && !instance_exec(payload, &route[:guard])
      raise InvalidTransition,
            "Guard condition failed for event '#{event}'"
    end

    # Validate target state exists
    target_state = route[:to]
    unless self.class._states.key?(target_state)
      raise UnknownState, "Target state '#{target_state}' is not defined"
    end

    transition_to(target_state, event, payload)
  end

  # Force set state without transition validation (use with caution)
  # @param state [Symbol] The state to set
  def force_state!(state)
    state = state.to_sym
    raise UnknownState, "Unknown state: #{state}" unless self.class._states.key?(state)

    @current_state = state
    @state_entered_at = Time.now.utc
  end

  
  # Find the matching route for the current state
  def find_route(transition, from_state)
    routes = transition[:routes] || [transition]
    routes.find { |r| r[:from].include?(from_state) } || transition
  end

  def transition_to(new_state, event, payload)
    old_state = current_state
    now = Time.now.utc

    # Run exit hook for old state
    exit_hook = self.class._exit_hooks[old_state]
    instance_exec(&exit_hook) if exit_hook

    # Record in history
    state_history << {
      from: old_state,
      to: new_state,
      event: event,
      payload: payload,
      transitioned_at: now,
      duration_in_state: @state_entered_at ? (now - @state_entered_at) : 0
    }

    # Update state
    @current_state = new_state
    @state_entered_at = now

    # Run transition hooks
    self.class._transition_hooks.each do |hook|
      instance_exec(old_state, new_state, event, payload, &hook)
    end

    # Run enter hook for new state
    enter_hook = self.class._enter_hooks[new_state]
    instance_exec(&enter_hook) if enter_hook

    new_state
  end
end

