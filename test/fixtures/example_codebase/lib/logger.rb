# frozen_string_literal: true

# Simple logging utility for application-wide logging.
# Completely unrelated to math operations - used for debugging and audit trails.
class Logger
  LEVELS = { debug: 0, info: 1, warn: 2, error: 3, fatal: 4 }.freeze

  attr_reader :level, :output, :entries

  def initialize(level: :info, output: $stdout)
    @level = level
    @output = output
    @entries = []
  end

  def debug(message)
    log(:debug, message)
  end

  def info(message)
    log(:info, message)
  end

  def warn(message)
    log(:warn, message)
  end

  def error(message)
    log(:error, message)
  end

  def fatal(message)
    log(:fatal, message)
  end

  def log(level, message)
    return unless should_log?(level)

    entry = format_entry(level, message)
    @entries << entry
    output.puts(entry)
    entry
  end

  def clear!
    @entries = []
  end

  def entries_at_level(level)
    min_level = LEVELS[level]
    @entries.select do |entry|
      entry_level = entry.match(/\[(\w+)\]/)[1].downcase.to_sym
      LEVELS[entry_level] >= min_level
    end
  end

  private

  def should_log?(msg_level)
    LEVELS[msg_level] >= LEVELS[@level]
  end

  def format_entry(level, message)
    timestamp = Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
    "[#{timestamp}] [#{level.to_s.upcase}] #{message}"
  end
end

