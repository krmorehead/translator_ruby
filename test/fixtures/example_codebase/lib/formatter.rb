# frozen_string_literal: true

# Formatter class for displaying numbers in various formats.
# Uses Calculator for mathematical operations before formatting.
class Formatter
  attr_reader :calculator

  # Initialize with an optional calculator instance
  # @param calculator [Calculator] Calculator instance for math operations
  def initialize(calculator: nil)
    @calculator = calculator || Calculator.new
  end

  # Format a number as currency
  # @param value [Numeric] The value to format
  # @param currency [String] Currency symbol (default: "$")
  # @param decimals [Integer] Number of decimal places (default: 2)
  # @return [String] Formatted currency string
  def currency(value, currency: "$", decimals: 2)
    formatted = format("%.#{decimals}f", value)
    "#{currency}#{formatted}"
  end

  # Format a number as a percentage string
  # @param value [Numeric] The value (0-100 scale)
  # @param decimals [Integer] Number of decimal places (default: 1)
  # @return [String] Formatted percentage string
  def percent(value, decimals: 1)
    formatted = format("%.#{decimals}f", value)
    "#{formatted}%"
  end

  # Format a number with thousand separators
  # @param value [Numeric] The value to format
  # @param separator [String] Thousand separator (default: ",")
  # @return [String] Formatted number string
  def with_separators(value, separator: ",")
    integer_part = value.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\\1#{separator}").reverse

    if value.is_a?(Float)
      decimal_part = format("%.2f", value).split(".").last
      "#{integer_part}.#{decimal_part}"
    else
      integer_part
    end
  end

  # Calculate and format a percentage change between two values
  # @param old_value [Numeric] The original value
  # @param new_value [Numeric] The new value
  # @return [String] Formatted percentage change with + or - prefix
  def percentage_change(old_value, new_value)
    return "N/A" if old_value.zero?

    difference = calculator.subtract(new_value, old_value)
    change = calculator.divide(difference, old_value)
    change_percent = calculator.multiply(change, 100)

    prefix = change_percent.positive? ? "+" : ""
    "#{prefix}#{percent(change_percent)}"
  end

  # Format a ratio as "X:Y" notation
  # @param numerator [Numeric] The numerator
  # @param denominator [Numeric] The denominator
  # @param simplify [Boolean] Whether to simplify the ratio
  # @return [String] Formatted ratio string
  def ratio(numerator, denominator, simplify: false)
    if simplify
      gcd = numerator.gcd(denominator)
      numerator = numerator / gcd
      denominator = denominator / gcd
    end

    "#{numerator}:#{denominator}"
  end
end

