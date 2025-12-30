# frozen_string_literal: true

# Notification service for sending alerts and messages to users.
# Supports multiple channels: email, SMS, and push notifications.
# Completely unrelated to math/calculation operations.
class NotificationService
  class DeliveryError < StandardError; end

  attr_reader :pending_notifications, :sent_notifications, :channels

  CHANNELS = [:email, :sms, :push].freeze

  def initialize(channels: CHANNELS)
    @channels = channels
    @pending_notifications = []
    @sent_notifications = []
    @subscribers = Hash.new { |h, k| h[k] = [] }
  end

  def subscribe(user_id:, channel:, address:)
    raise ArgumentError, "Invalid channel" unless CHANNELS.include?(channel)

    @subscribers[user_id] << { channel: channel, address: address }
  end

  def unsubscribe(user_id:, channel: nil)
    if channel
      @subscribers[user_id].delete_if { |s| s[:channel] == channel }
    else
      @subscribers.delete(user_id)
    end
  end

  def notify(user_id:, subject:, body:, channel: nil, priority: :normal)
    subscriptions = @subscribers[user_id]
    return false if subscriptions.empty?

    target_subs = channel ? subscriptions.select { |s| s[:channel] == channel } : subscriptions

    target_subs.each do |sub|
      notification = {
        id: SecureRandom.uuid,
        user_id: user_id,
        channel: sub[:channel],
        address: sub[:address],
        subject: subject,
        body: body,
        priority: priority,
        created_at: Time.now.utc,
        status: :pending
      }
      @pending_notifications << notification
    end

    true
  end

  def broadcast(subject:, body:, channel: nil, priority: :normal)
    @subscribers.each_key do |user_id|
      notify(user_id: user_id, subject: subject, body: body, channel: channel, priority: priority)
    end
  end

  def process_pending
    results = { success: 0, failed: 0 }

    @pending_notifications.dup.each do |notification|
      begin
        deliver(notification)
        notification[:status] = :sent
        notification[:sent_at] = Time.now.utc
        @sent_notifications << notification
        @pending_notifications.delete(notification)
        results[:success] += 1
      rescue DeliveryError => e
        notification[:status] = :failed
        notification[:error] = e.message
        results[:failed] += 1
      end
    end

    results
  end

  def notification_history(user_id: nil, channel: nil, limit: 50)
    history = @sent_notifications.dup

    history = history.select { |n| n[:user_id] == user_id } if user_id
    history = history.select { |n| n[:channel] == channel } if channel

    history.last(limit)
  end

  def pending_count
    @pending_notifications.size
  end

  def clear_pending!
    @pending_notifications.clear
  end

  
  def deliver(notification)
    # Simulate delivery based on channel
    case notification[:channel]
    when :email
      deliver_email(notification)
    when :sms
      deliver_sms(notification)
    when :push
      deliver_push(notification)
    else
      raise DeliveryError, "Unknown channel: #{notification[:channel]}"
    end
  end

  def deliver_email(notification)
    # Simulate email delivery
    # In real implementation, would use ActionMailer or similar
    true
  end

  def deliver_sms(notification)
    # Simulate SMS delivery
    # In real implementation, would use Twilio or similar
    true
  end

  def deliver_push(notification)
    # Simulate push notification
    # In real implementation, would use FCM/APNS
    true
  end
end

