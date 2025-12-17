require "test_helper"

class StateMachineTest < ActiveSupport::TestCase
  # Test class that includes StateMachine
  class TestMachine
    include StateMachine

    initial_state :idle

    state :idle, description: "Waiting"
    state :starting, description: "Starting up"
    state :running, description: "Actively running"
    state :paused, description: "Temporarily paused"
    state :stopped, description: "Stopped"
    state :failed, description: "Error occurred"

    transition from: :idle, to: :starting, on: :start
    transition from: :starting, to: :running, on: :started
    transition from: :running, to: :paused, on: :pause
    transition from: :paused, to: :running, on: :resume
    transition from: [:running, :paused], to: :stopped, on: :stop
    transition from: [:starting, :running, :paused], to: :failed, on: :error
    transition from: :failed, to: :idle, on: :reset

    def initialize
      initialize_state_machine
    end
  end

  # Test class with guards
  class GuardedMachine
    include StateMachine

    attr_accessor :ready

    initial_state :waiting

    state :waiting
    state :processing
    state :done

    transition from: :waiting, to: :processing, on: :process do |payload|
      ready && payload[:data].present?
    end

    transition from: :processing, to: :done, on: :complete

    def initialize
      initialize_state_machine
      @ready = false
    end
  end

  # Test class with hooks
  class HookedMachine
    include StateMachine

    attr_reader :enter_log, :exit_log, :transition_log

    initial_state :first

    state :first
    state :second
    state :third

    transition from: :first, to: :second, on: :next
    transition from: :second, to: :third, on: :next

    on_enter :second do
      @enter_log << "entered second"
    end

    on_exit :second do
      @exit_log << "exited second"
    end

    on_transition do |from, to, event, payload|
      @transition_log << { from: from, to: to, event: event, payload: payload }
    end

    def initialize
      initialize_state_machine
      @enter_log = []
      @exit_log = []
      @transition_log = []
    end
  end

  # Test class with phases
  class PhasedMachine
    include StateMachine

    initial_state :pending

    state :pending, phase: nil
    state :setup, phase: :initialization
    state :work, phase: :processing
    state :cleanup, phase: :finalization
    state :done, phase: nil

    transition from: :pending, to: :setup, on: :begin
    transition from: :setup, to: :work, on: :start_work
    transition from: :work, to: :cleanup, on: :finish_work
    transition from: :cleanup, to: :done, on: :complete

    def initialize
      initialize_state_machine
    end
  end

  # Basic state machine tests
  test "initializes with initial state" do
    machine = TestMachine.new
    assert_equal :idle, machine.current_state
  end

  test "valid transitions work" do
    machine = TestMachine.new

    assert_equal :idle, machine.current_state

    machine.trigger(:start)
    assert_equal :starting, machine.current_state

    machine.trigger(:started)
    assert_equal :running, machine.current_state

    machine.trigger(:pause)
    assert_equal :paused, machine.current_state

    machine.trigger(:resume)
    assert_equal :running, machine.current_state

    machine.trigger(:stop)
    assert_equal :stopped, machine.current_state
  end

  test "invalid transitions raise InvalidTransition" do
    machine = TestMachine.new

    assert_raises(StateMachine::InvalidTransition) do
      machine.trigger(:pause) # Can't pause from idle
    end

    assert_raises(StateMachine::InvalidTransition) do
      machine.trigger(:stop) # Can't stop from idle
    end
  end

  test "unknown events raise UnknownEvent" do
    machine = TestMachine.new

    assert_raises(StateMachine::UnknownEvent) do
      machine.trigger(:nonexistent_event)
    end
  end

  test "transitions from multiple source states work" do
    machine = TestMachine.new

    # Can stop from running
    machine.trigger(:start)
    machine.trigger(:started)
    machine.trigger(:stop)
    assert_equal :stopped, machine.current_state

    # Reset and try stopping from paused
    machine2 = TestMachine.new
    machine2.trigger(:start)
    machine2.trigger(:started)
    machine2.trigger(:pause)
    machine2.trigger(:stop)
    assert_equal :stopped, machine2.current_state
  end

  test "state history is tracked" do
    machine = TestMachine.new
    machine.trigger(:start)
    machine.trigger(:started)
    machine.trigger(:pause)

    history = machine.state_history
    assert_equal 3, history.size

    assert_equal :idle, history[0][:from]
    assert_equal :starting, history[0][:to]
    assert_equal :start, history[0][:event]

    assert_equal :starting, history[1][:from]
    assert_equal :running, history[1][:to]

    assert_equal :running, history[2][:from]
    assert_equal :paused, history[2][:to]
  end

  test "in_state? checks current state" do
    machine = TestMachine.new

    assert machine.in_state?(:idle)
    refute machine.in_state?(:running)

    machine.trigger(:start)
    assert machine.in_state?(:starting)
    refute machine.in_state?(:idle)
  end

  test "can_trigger? checks if event is valid" do
    machine = TestMachine.new

    assert machine.can_trigger?(:start)
    refute machine.can_trigger?(:pause)
    refute machine.can_trigger?(:stop)
  end

  test "available_events returns triggerable events" do
    machine = TestMachine.new

    assert_equal [:start], machine.available_events

    machine.trigger(:start)
    assert_includes machine.available_events, :started
    assert_includes machine.available_events, :error

    machine.trigger(:started)
    assert_includes machine.available_events, :pause
    assert_includes machine.available_events, :stop
    assert_includes machine.available_events, :error
  end

  # Guard tests
  test "guards block transitions when returning false" do
    machine = GuardedMachine.new
    machine.ready = false

    assert_raises(StateMachine::InvalidTransition) do
      machine.trigger(:process, data: "test")
    end

    machine.ready = true
    assert_raises(StateMachine::InvalidTransition) do
      machine.trigger(:process, data: nil) # data not present
    end

    # Should work when both conditions are met
    machine.trigger(:process, data: "test")
    assert_equal :processing, machine.current_state
  end

  test "guards receive payload" do
    machine = GuardedMachine.new
    machine.ready = true

    # Should fail without data
    assert_raises(StateMachine::InvalidTransition) do
      machine.trigger(:process)
    end

    # Should succeed with data
    machine.trigger(:process, data: "some data")
    assert_equal :processing, machine.current_state
  end

  # Hook tests
  test "on_enter hooks are called" do
    machine = HookedMachine.new

    assert_empty machine.enter_log

    machine.trigger(:next) # first -> second
    assert_equal ["entered second"], machine.enter_log
  end

  test "on_exit hooks are called" do
    machine = HookedMachine.new

    machine.trigger(:next) # first -> second
    assert_empty machine.exit_log

    machine.trigger(:next) # second -> third
    assert_equal ["exited second"], machine.exit_log
  end

  test "on_transition hooks are called for every transition" do
    machine = HookedMachine.new

    machine.trigger(:next)
    machine.trigger(:next)

    assert_equal 2, machine.transition_log.size

    assert_equal :first, machine.transition_log[0][:from]
    assert_equal :second, machine.transition_log[0][:to]
    assert_equal :next, machine.transition_log[0][:event]

    assert_equal :second, machine.transition_log[1][:from]
    assert_equal :third, machine.transition_log[1][:to]
  end

  test "hooks receive correct order - exit, transition, enter" do
    execution_order = []

    test_class = Class.new do
      include StateMachine

      initial_state :a
      state :a
      state :b

      transition from: :a, to: :b, on: :go

      define_method(:execution_order) { execution_order }

      on_exit :a do
        execution_order << :exit_a
      end

      on_enter :b do
        execution_order << :enter_b
      end

      on_transition do |_from, _to, _event, _payload|
        execution_order << :transition
      end

      define_method(:initialize) do
        initialize_state_machine
      end
    end

    machine = test_class.new
    machine.trigger(:go)

    assert_equal [:exit_a, :transition, :enter_b], execution_order
  end

  # Phase tests
  test "current_phase returns state phase" do
    machine = PhasedMachine.new

    assert_nil machine.current_phase

    machine.trigger(:begin)
    assert_equal :initialization, machine.current_phase

    machine.trigger(:start_work)
    assert_equal :processing, machine.current_phase

    machine.trigger(:finish_work)
    assert_equal :finalization, machine.current_phase

    machine.trigger(:complete)
    assert_nil machine.current_phase
  end

  # Class method tests
  test "states returns all defined states" do
    states = TestMachine.states
    assert_includes states, :idle
    assert_includes states, :running
    assert_includes states, :failed
    assert_equal 6, states.size
  end

  test "events returns all defined events" do
    events = TestMachine.events
    assert_includes events, :start
    assert_includes events, :stop
    assert_includes events, :error
  end

  test "state? checks if state is defined" do
    assert TestMachine.state?(:idle)
    assert TestMachine.state?(:running)
    refute TestMachine.state?(:nonexistent)
  end

  test "event? checks if event is defined" do
    assert TestMachine.event?(:start)
    assert TestMachine.event?(:stop)
    refute TestMachine.event?(:nonexistent)
  end

  test "transitions_from returns valid transitions" do
    transitions = TestMachine.transitions_from(:running)

    assert transitions.key?(:pause)
    assert transitions.key?(:stop)
    assert transitions.key?(:error)
    refute transitions.key?(:start)
  end

  # Force state tests
  test "force_state! sets state without validation" do
    machine = TestMachine.new

    machine.force_state!(:running)
    assert_equal :running, machine.current_state
    # History should be empty since we didn't transition
    assert_empty machine.state_history
  end

  test "force_state! raises for unknown state" do
    machine = TestMachine.new

    assert_raises(StateMachine::UnknownState) do
      machine.force_state!(:nonexistent)
    end
  end

  # State info tests
  test "current_state_info returns state metadata" do
    machine = TestMachine.new

    info = machine.current_state_info
    assert_equal :idle, info[:name]
    assert_equal "Waiting", info[:description]
  end

  # Inheritance tests
  test "subclasses can override states" do
    parent = Class.new do
      include StateMachine
      initial_state :a
      state :a
      state :b
      transition from: :a, to: :b, on: :go
    end

    child = Class.new(parent) do
      initial_state :x
      state :x
      state :y
      transition from: :x, to: :y, on: :proceed
    end

    parent_instance = parent.new
    parent_instance.send(:initialize_state_machine)
    assert_equal :a, parent_instance.current_state

    child_instance = child.new
    child_instance.send(:initialize_state_machine)
    assert_equal :x, child_instance.current_state
  end
end

