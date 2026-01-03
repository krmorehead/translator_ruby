/**
 * General-purpose utility for subscribing to worker execution progress via SSE.
 * Can be used by any worker (Sisyphus, Daedalus, ProjectPlanner, etc.)
 * 
 * Usage:
 *   import { subscribeToWorkerProgress } from './utils/workerProgressStream';
 * 
 *   const eventSource = subscribeToWorkerProgress({
 *     streamUrl: `/api/sisyphus/executions/${executionId}/stream`,
 *     onEvent: (event) => console.log('Progress:', event),
 *     onError: (error) => console.error('Error:', error),
 *     onComplete: (data) => console.log('Complete:', data)
 *   });
 * 
 *   // Later, to unsubscribe:
 *   eventSource.close();
 */

/**
 * Standard event types emitted by workers
 */
export const WORKER_EVENT_TYPES = {
  CONNECTED: 'connected',
  STARTED: 'started',
  MILESTONE_STARTED: 'milestone_started',
  MILESTONE_COMPLETED: 'milestone_completed',
  STEP_STARTED: 'step_started',
  STEP_COMPLETED: 'step_completed',
  STEP_FAILED: 'step_failed',
  FILE_CHANGED: 'file_changed',
  CHECKPOINT_CREATED: 'checkpoint_created',
  COMPLETED: 'completed',
  FAILED: 'failed',
  CANCELLED: 'cancelled',
  ERROR: 'error'
};

/**
 * Terminal event types that indicate execution has ended
 */
const TERMINAL_EVENTS = [
  WORKER_EVENT_TYPES.COMPLETED,
  WORKER_EVENT_TYPES.FAILED,
  WORKER_EVENT_TYPES.CANCELLED
];

/**
 * Subscribe to worker execution progress via Server-Sent Events
 * 
 * @param {Object} options - Configuration options
 * @param {string} options.streamUrl - The SSE endpoint URL
 * @param {Function} options.onEvent - Callback for each progress event
 * @param {Function} options.onError - Callback for errors
 * @param {Function} options.onComplete - Callback when stream closes
 * @param {boolean} options.autoReconnect - Whether to auto-reconnect on error (default: false)
 * @returns {EventSource} The EventSource object (call .close() to unsubscribe)
 */
export function subscribeToWorkerProgress({
  streamUrl,
  onEvent,
  onError,
  onComplete,
  autoReconnect = false
}) {
  if (!streamUrl) {
    throw new Error('streamUrl is required');
  }

  const eventSource = new EventSource(streamUrl);
  let isTerminated = false;

  // Handle connection
  eventSource.addEventListener(WORKER_EVENT_TYPES.CONNECTED, (event) => {
    try {
      const data = JSON.parse(event.data);
      console.log('[WorkerProgress] Connected:', data);
      
      if (onEvent) {
        onEvent({ ...data, event_type: WORKER_EVENT_TYPES.CONNECTED });
      }
    } catch (error) {
      console.error('[WorkerProgress] Failed to parse connected event:', error);
    }
  });

  // Handle all progress events
  Object.values(WORKER_EVENT_TYPES).forEach((eventType) => {
    eventSource.addEventListener(eventType, (event) => {
      try {
        const data = JSON.parse(event.data);
        
        if (onEvent) {
          onEvent({ ...data, event_type: eventType });
        }

        // Close on terminal events
        if (TERMINAL_EVENTS.includes(eventType)) {
          isTerminated = true;
          eventSource.close();
          
          if (onComplete) {
            onComplete({ ...data, event_type: eventType });
          }
        }
      } catch (error) {
        console.error(`[WorkerProgress] Failed to parse ${eventType} event:`, error);
      }
    });
  });

  // Handle errors
  eventSource.onerror = (error) => {
    console.error('[WorkerProgress] SSE error:', error);

    // Don't reconnect if we've already received a terminal event
    if (isTerminated) {
      eventSource.close();
      return;
    }

    if (onError) {
      onError(error);
    }

    // Close if not auto-reconnecting
    if (!autoReconnect) {
      eventSource.close();
    }
  };

  return eventSource;
}

/**
 * Create a progress event handler that updates Zustand store
 * 
 * @param {Function} updateFn - Zustand set function
 * @param {string} executionKey - Key in store for execution state (e.g., 'currentExecution')
 * @returns {Function} Event handler function
 */
export function createStoreProgressHandler(updateFn, executionKey = 'currentExecution') {
  return (event) => {
    const { event_type, data } = event;

    switch (event_type) {
      case WORKER_EVENT_TYPES.STARTED:
        updateFn((state) => ({
          [executionKey]: {
            ...state[executionKey],
            status: 'running',
            started_at: event.timestamp
          }
        }));
        break;

      case WORKER_EVENT_TYPES.MILESTONE_STARTED:
        updateFn((state) => ({
          [executionKey]: {
            ...state[executionKey],
            current_milestone: data.milestone_title
          }
        }));
        break;

      case WORKER_EVENT_TYPES.STEP_STARTED:
        updateFn((state) => ({
          [executionKey]: {
            ...state[executionKey],
            current_step: data.step_title
          }
        }));
        break;

      case WORKER_EVENT_TYPES.STEP_COMPLETED:
        updateFn((state) => ({
          [executionKey]: {
            ...state[executionKey],
            progress_percentage: data.progress_percentage,
            files_changed: [
              ...(state[executionKey]?.files_changed || []),
              ...(data.files_changed || [])
            ]
          }
        }));
        break;

      case WORKER_EVENT_TYPES.CHECKPOINT_CREATED:
        updateFn((state) => ({
          [executionKey]: {
            ...state[executionKey],
            checkpoint_ids: [
              ...(state[executionKey]?.checkpoint_ids || []),
              data.checkpoint_id
            ]
          }
        }));
        break;

      case WORKER_EVENT_TYPES.COMPLETED:
        updateFn((state) => ({
          [executionKey]: {
            ...state[executionKey],
            status: 'complete',
            completed_at: event.timestamp
          }
        }));
        break;

      case WORKER_EVENT_TYPES.FAILED:
        updateFn((state) => ({
          [executionKey]: {
            ...state[executionKey],
            status: 'failed',
            error: data.error_message,
            completed_at: event.timestamp
          }
        }));
        break;

      case WORKER_EVENT_TYPES.CANCELLED:
        updateFn((state) => ({
          [executionKey]: {
            ...state[executionKey],
            status: 'failed',
            error: 'Cancelled by user',
            completed_at: event.timestamp
          }
        }));
        break;

      default:
        // Log unhandled event types for debugging
        console.log(`[WorkerProgress] Unhandled event: ${event_type}`, data);
    }
  };
}

/**
 * Format progress event for display
 * 
 * @param {Object} event - Progress event
 * @returns {string} Formatted message
 */
export function formatProgressEvent(event) {
  const { event_type, data } = event;

  switch (event_type) {
    case WORKER_EVENT_TYPES.STARTED:
      return `Execution started`;
    
    case WORKER_EVENT_TYPES.MILESTONE_STARTED:
      return `Starting milestone ${data.milestone_number}: ${data.milestone_title}`;
    
    case WORKER_EVENT_TYPES.MILESTONE_COMPLETED:
      return `Completed milestone ${data.milestone_number}`;
    
    case WORKER_EVENT_TYPES.STEP_STARTED:
      return `Starting step ${data.step_number}: ${data.step_title}`;
    
    case WORKER_EVENT_TYPES.STEP_COMPLETED:
      return `Completed step ${data.step_number} (${data.progress_percentage}%)`;
    
    case WORKER_EVENT_TYPES.STEP_FAILED:
      return `Step ${data.step_number} failed: ${data.error_message}`;
    
    case WORKER_EVENT_TYPES.FILE_CHANGED:
      return `File ${data.change_type}: ${data.file_path}`;
    
    case WORKER_EVENT_TYPES.CHECKPOINT_CREATED:
      return `Checkpoint created: ${data.message}`;
    
    case WORKER_EVENT_TYPES.COMPLETED:
      return `Execution completed (${data.total_steps} steps, ${data.total_files_changed} files changed)`;
    
    case WORKER_EVENT_TYPES.FAILED:
      return `Execution failed: ${data.error_message}`;
    
    case WORKER_EVENT_TYPES.CANCELLED:
      return `Execution cancelled`;
    
    default:
      return `Event: ${event_type}`;
  }
}

