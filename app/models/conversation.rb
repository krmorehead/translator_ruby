# frozen_string_literal: true

# Aggregates ordered chat messages.
# Provides append helpers and serialization for API responses.
class Conversation
  attr_reader :messages

  def initialize(messages: [])
    @messages = Array(messages).map { |msg| coerce_message(msg) }
  end

  def add_message(message)
    @messages << coerce_message(message)
    self
  end
  alias << add_message

  def to_h
    { messages: messages.map(&:to_h) }
  end

  private

  def coerce_message(message)
    return message if message.is_a?(Message)

    raise ArgumentError, "message must be a Message" unless message.is_a?(Hash)

    Message.new(**message.transform_keys(&:to_sym))
  end
end
