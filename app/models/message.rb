# frozen_string_literal: true

# Plain Ruby value object describing a chat message exchanged between user/assistant.
class Message
  attr_reader :source, :target, :message, :context

  def initialize(source:, target:, message:, context: nil)
    @source = normalize_string(source, "source")
    @target = normalize_string(target, "target")
    @message = normalize_string(message, "message")
    @context = normalize_context(context)
  end

  def to_h
    {
      source: source,
      target: target,
      message: message,
      context: context
    }
  end

  private

  def normalize_string(value, field)
    string = value.to_s.strip
    raise ArgumentError, "#{field} required" if string.empty?

    string
  end

  def normalize_context(value)
    return nil if value.nil?
    return value if value.is_a?(Hash)

    raise ArgumentError, "context must be a Hash or nil"
  end
end

