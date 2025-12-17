# frozen_string_literal: true

# MathService provides high-level mathematical operations with formatted output.
# This service combines Calculator for computations and Formatter for display.
#
# Architecture:
#   MathService
#       ├── Calculator (performs arithmetic)
#       └── Formatter (formats output)
#             └── Calculator (used for percentage calculations)
#
class MathService
  attr_reader :calculator, :formatter

  # Initialize the math service
  # @param calculator [Calculator] Optional calculator instance
  # @param formatter [Formatter] Optional formatter instance
  def initialize(calculator: nil, formatter: nil)
    @calculator = calculator || Calculator.new
    @formatter = formatter || Formatter.new(calculator: @calculator)
  end

  # Calculate the total from a list of items with quantities and prices
  # @param items [Array<Hash>] Array of { quantity:, price: } hashes
  # @return [Hash] Result with raw total and formatted currency
  def calculate_total(items)
    total = items.sum do |item|
      calculator.multiply(item[:quantity], item[:price])
    end

    {
      raw: total,
      formatted: formatter.currency(total)
    }
  end

  # Calculate statistics for a dataset
  # @param numbers [Array<Numeric>] The dataset
  # @return [Hash] Statistics including min, max, sum, average
  def calculate_statistics(numbers)
    return empty_statistics if numbers.empty?

    {
      count: numbers.size,
      min: numbers.min,
      max: numbers.max,
      sum: numbers.sum,
      average: calculator.average(numbers),
      formatted_average: formatter.currency(calculator.average(numbers))
    }
  end

  # Calculate discount and return formatted results
  # @param original_price [Numeric] Original price
  # @param discount_percent [Numeric] Discount percentage (0-100)
  # @return [Hash] Discount details
  def apply_discount(original_price, discount_percent)
    discount_amount = calculator.percentage(original_price, discount_percent)
    final_price = calculator.subtract(original_price, discount_amount)

    {
      original: formatter.currency(original_price),
      discount: formatter.percent(discount_percent),
      savings: formatter.currency(discount_amount),
      final: formatter.currency(final_price),
      raw_final: final_price
    }
  end

  # Compare two values and show the change
  # @param before [Numeric] Value before
  # @param after [Numeric] Value after
  # @return [Hash] Comparison results
  def compare_values(before, after)
    {
      before: formatter.currency(before),
      after: formatter.currency(after),
      change: formatter.percentage_change(before, after),
      difference: formatter.currency(calculator.subtract(after, before))
    }
  end

  # Calculate compound interest
  # @param principal [Numeric] Initial investment
  # @param rate [Numeric] Annual interest rate (as percentage)
  # @param years [Integer] Number of years
  # @param compounds_per_year [Integer] Times compounded per year
  # @return [Hash] Compound interest results
  def compound_interest(principal, rate, years, compounds_per_year: 12)
    # Formula: A = P(1 + r/n)^(nt)
    r = calculator.divide(rate, 100)
    n = compounds_per_year
    t = years

    rate_per_period = calculator.divide(r, n)
    total_periods = calculator.multiply(n, t)

    final_amount = principal * ((1 + rate_per_period) ** total_periods)
    interest_earned = calculator.subtract(final_amount, principal)

    {
      principal: formatter.currency(principal),
      final_amount: formatter.currency(final_amount),
      interest_earned: formatter.currency(interest_earned),
      effective_rate: formatter.percent(calculator.multiply(
        calculator.divide(interest_earned, principal), 100
      )),
      raw_final: final_amount
    }
  end

  private

  def empty_statistics
    {
      count: 0,
      min: nil,
      max: nil,
      sum: 0,
      average: nil,
      formatted_average: "N/A"
    }
  end
end

