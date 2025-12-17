# frozen_string_literal: true

# Simple calculator class that performs basic arithmetic operations.
# This is the foundational math utility used by other services.
class Calculator
  # Error raised when attempting to divide by zero
  class DivisionByZeroError < StandardError; end

  # Add two numbers together
  # @param a [Numeric] First number
  # @param b [Numeric] Second number
  # @return [Numeric] Sum of a and b
  def add(a, b)
    a + b
  end

  # Subtract b from a
  # @param a [Numeric] Number to subtract from
  # @param b [Numeric] Number to subtract
  # @return [Numeric] Difference of a and b
  def subtract(a, b)
    a - b
  end

  # Multiply two numbers
  # @param a [Numeric] First factor
  # @param b [Numeric] Second factor
  # @return [Numeric] Product of a and b
  def multiply(a, b)
    a * b
  end

  # Divide a by b
  # @param a [Numeric] Dividend
  # @param b [Numeric] Divisor
  # @return [Float] Quotient of a divided by b
  # @raise [DivisionByZeroError] if b is zero
  def divide(a, b)
    raise DivisionByZeroError, "Cannot divide by zero" if b.zero?

    a.to_f / b
  end

  # Calculate the percentage of a value
  # @param value [Numeric] The value to calculate percentage of
  # @param percentage [Numeric] The percentage to calculate
  # @return [Float] The percentage of the value
  def percentage(value, percentage)
    multiply(value, percentage) / 100.0
  end

  # Calculate the average of an array of numbers
  # @param numbers [Array<Numeric>] Array of numbers to average
  # @return [Float] The arithmetic mean
  # @raise [ArgumentError] if array is empty
  def average(numbers)
    raise ArgumentError, "Cannot calculate average of empty array" if numbers.empty?

    divide(numbers.sum, numbers.size)
  end
end

