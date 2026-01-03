# frozen_string_literal: true

# Concern for controllers that need to stream execution progress via SSE.
# Provides a reusable method for streaming worker progress events.
#
# Usage:
#   class MyWorkerController < ApplicationController
#     include ActionController::Live
#     include StreamableExecution
#
#     def stream_progress
#       stream_execution_progress(params[:execution_id])
#     end
#   end
#
# This concern can be used by any worker controller (Sisyphus, Daedalus, etc.)
# to provide real-time progress updates to the frontend.
module StreamableExecution
  extend ActiveSupport::Concern

  included do
    # Ensure ActionController::Live is included
    unless ancestors.include?(ActionController::Live)
      raise "StreamableExecution requires ActionController::Live to be included"
    end
  end

  # Stream execution progress via Server-Sent Events (SSE)
  #
  # @param execution_id [String] The execution identifier to stream
  # @param broadcaster [ExecutionProgressBroadcaster, nil] Optional custom broadcaster
  # @return [void]
  def stream_execution_progress(execution_id, broadcaster: nil)
    # Set SSE headers
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["X-Accel-Buffering"] = "no" # Disable nginx buffering

    # Create SSE stream
    sse = SSE.new(response.stream, retry: 300, event: "message")

    begin
      # Send initial connection event
      sse.write(
        { type: "connected", execution_id: execution_id, timestamp: Time.now.utc.iso8601 },
        event: "connected"
      )

      # Use provided broadcaster or create new one
      progress_broadcaster = broadcaster || ExecutionProgressBroadcaster.new

      # Subscribe to progress events
      progress_broadcaster.subscribe(execution_id: execution_id) do |event|
        # Write event to SSE stream
        sse.write(event, event: event[:event_type].to_s)

        # Close stream on terminal events
        if terminal_event?(event[:event_type])
          break
        end
      end
    rescue IOError, ActionController::Live::ClientDisconnected
      # Client disconnected - this is normal
      Rails.logger.info "SSE client disconnected: #{execution_id}"
    rescue StandardError => e
      # Log unexpected errors
      Rails.logger.error "SSE streaming error: #{e.message}\n#{e.backtrace.join("\n")}"
      
      # Try to send error event to client
      begin
        sse.write(
          { type: "error", message: "Streaming error occurred", timestamp: Time.now.utc.iso8601 },
          event: "error"
        )
      rescue StandardError
        # Client may have disconnected, ignore
      end
    ensure
      # Always close the stream
      sse&.close
    end
  end

  private

  # Check if an event type is terminal (should close the stream)
  #
  # @param event_type [Symbol] The event type
  # @return [Boolean] true if terminal event
  def terminal_event?(event_type)
    %i[completed failed cancelled].include?(event_type)
  end
end

