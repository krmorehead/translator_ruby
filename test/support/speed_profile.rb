# frozen_string_literal: true

# SpeedProfile module provides test speed categorization and enforcement
# Following OOP patterns from docs/references/oop-patterns.md
module SpeedProfile
  # Constants at top - frozen for immutability
  SPEED_LEVELS = [
    FAST = :fast,
    MEDIUM = :medium,
    SLOW = :slow
  ].freeze

  SPEED_LIMITS = {
    FAST => 10,
    MEDIUM => 60,
    SLOW => 120
  }.freeze

  def self.included(base)
    base.class_eval do
      # Store speed profiles per test method
      @speed_profiles = {}
      @test_definition_count = 0
      
      class << self
        attr_accessor :speed_profiles, :test_definition_count
        
        def speed_profile(level)
          # Strict validation with descriptive errors
          unless level.is_a?(Symbol)
            raise ArgumentError, "Speed profile must be a Symbol, got #{level.class}"
          end
          unless SpeedProfile::SPEED_LEVELS.include?(level)
            raise ArgumentError, "Invalid speed profile: #{level}. Valid profiles: #{SpeedProfile::SPEED_LEVELS.join(', ')}"
          end

          # Store for the next test method that will be defined
          @next_speed_profile = level
        end
        
        # Hook into Minitest::Spec test method
        def test(name, &block)
          # Capture the speed profile before calling super
          speed = @next_speed_profile
          @next_speed_profile = nil
          
          # Increment counter
          @test_definition_count ||= 0
          @test_definition_count += 1
          test_num = @test_definition_count
          
          # Call the original test method which creates the test
          result = super(name, &block)
          
          # Store the speed profile with the test method name
          # Minitest converts "test name" to "test_0001_test name" (keeps original name)
          if speed
            # Build the method name that Minitest will create
            test_method_name = :"test_#{sprintf('%04d', test_num)}_#{name}"
            @speed_profiles ||= {}
            @speed_profiles[test_method_name] = speed
          end
          
          result
        end
        
        def speed_profile_for(test_name)
          @speed_profiles&.[](test_name.to_sym)
        end
      end

      setup do
        validate_speed_profile!
        check_speed_filter!
        start_timeout_enforcement!
      end

      teardown do
        stop_timeout_enforcement!
      end
    end
  end

  private

  def validate_speed_profile!
    # Get speed profile for this test
    speed = self.class.speed_profile_for(name)
    
    return if speed && SpeedProfile::SPEED_LEVELS.include?(speed)

    raise ArgumentError, "Test '#{name}' must declare speed_profile. " \
                         "Add 'speed_profile :fast', 'speed_profile :medium', or 'speed_profile :slow' " \
                         "before the test definition."
  end

  def check_speed_filter!
    filter = ENV["TEST_SPEED_FILTER"]
    return if filter.nil? || filter == "all"

    filter_symbol = filter.to_sym
    unless SpeedProfile::SPEED_LEVELS.include?(filter_symbol)
      raise ArgumentError, "Invalid TEST_SPEED_FILTER: #{filter}. Valid values: fast, medium, slow, all"
    end

    current_level = self.class.speed_profile_for(name)
    return unless current_level
    return if should_run_test?(current_level, filter_symbol)

    skip "Skipping #{current_level} test - filter is set to #{filter}"
  end

  def should_run_test?(test_level, filter_level)
    # Define level ordering
    level_order = { fast: 1, medium: 2, slow: 3 }

    # Run test if it matches the filter or is faster than the filter
    level_order[test_level] <= level_order[filter_level]
  end

  def start_timeout_enforcement!
    level = self.class.speed_profile_for(name)
    return unless level && SpeedProfile::SPEED_LEVELS.include?(level)
    
    timeout_seconds = SpeedProfile::SPEED_LIMITS[level]

    @timeout_thread = Thread.new do
      sleep timeout_seconds
      if @test_started && !@test_finished
        test_info = "Test '#{name}' exceeded #{level} speed profile SLA (#{timeout_seconds}s)"
        Rails.logger.error(test_info) if defined?(Rails)
        # Force test failure by raising in the main thread
        Thread.main.raise(Minitest::Assertion, test_info)
      end
    end

    @test_started = true
    @test_finished = false
  end

  def stop_timeout_enforcement!
    @test_finished = true
    @timeout_thread&.kill
    @timeout_thread = nil
  end
end
