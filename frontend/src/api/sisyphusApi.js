const jsonHeaders = { "Content-Type": "application/json" };

async function handleJson(response) {
  const body = await response.json();
  if (!response.ok) {
    throw new Error(body.error);
  }
  return body;
}

export async function createExecution({ planPath, projectPath, options = {} }) {
  const response = await fetch("/api/sisyphus/executions", {
    method: "POST",
    headers: jsonHeaders,
    body: JSON.stringify({
      plan_path: planPath,
      project_path: projectPath,
      options
    })
  });
  return handleJson(response);
}

export async function getExecutionState(executionId) {
  const response = await fetch(`/api/sisyphus/executions/${executionId}`);
  return handleJson(response);
}

export async function listExecutions(limit = 50) {
  const response = await fetch(`/api/sisyphus/executions?limit=${limit}`);
  return handleJson(response);
}

export async function cancelExecution(executionId) {
  const response = await fetch(`/api/sisyphus/executions/${executionId}`, {
    method: "DELETE"
  });
  return handleJson(response);
}

export async function getFileTree({ path, maxDepth, extensions, ignorePatterns }) {
  const params = new URLSearchParams();
  params.append("path", path);
  if (maxDepth !== undefined) params.append("max_depth", maxDepth);
  if (extensions) params.append("extensions", JSON.stringify(extensions));
  if (ignorePatterns) params.append("ignore_patterns", JSON.stringify(ignorePatterns));

  const response = await fetch(`/api/sisyphus/filesystem/tree?${params.toString()}`);
  return handleJson(response);
}

export async function readFile(path) {
  const params = new URLSearchParams({ path });
  const response = await fetch(`/api/sisyphus/filesystem/read?${params.toString()}`);
  return handleJson(response);
}

export async function searchFiles({ pattern, path, extensions, maxResults, caseInsensitive, wholeWord, contextLines }) {
  const params = new URLSearchParams();
  params.append("pattern", pattern);
  params.append("path", path);
  if (extensions) params.append("extensions", JSON.stringify(extensions));
  if (maxResults !== undefined) params.append("max_results", maxResults);
  if (caseInsensitive !== undefined) params.append("case_insensitive", caseInsensitive);
  if (wholeWord !== undefined) params.append("whole_word", wholeWord);
  if (contextLines !== undefined) params.append("context_lines", contextLines);

  const response = await fetch(`/api/sisyphus/filesystem/search?${params.toString()}`);
  return handleJson(response);
}

export async function getConfig() {
  const response = await fetch("/api/sisyphus/config");
  return handleJson(response);
}

export async function validateConfig(capability) {
  const response = await fetch("/api/sisyphus/config/validate", {
    method: "POST",
    headers: jsonHeaders,
    body: JSON.stringify({
      name: capability.name,
      model_name: capability.modelName,
      port: capability.port,
      max_context: capability.maxContext,
      base_url: capability.baseUrl
    })
  });
  return handleJson(response);
}

export async function testConnection(capabilityName) {
  const response = await fetch("/api/sisyphus/config/test", {
    method: "POST",
    headers: jsonHeaders,
    body: JSON.stringify({ capability_name: capabilityName })
  });
  return handleJson(response);
}

// Approval API functions
import { ApprovalRequest } from "../models/ApprovalRequest";

/**
 * Get pending approval for an execution
 * @param {string} executionId - Execution ID
 * @returns {Promise<ApprovalRequest|null>} ApprovalRequest instance or null
 * @throws {Error} If executionId is invalid
 */
export async function getPendingApproval(executionId) {
  if (!executionId || typeof executionId !== "string") {
    throw new Error("executionId must be a non-empty string");
  }

  const params = new URLSearchParams({ execution_id: executionId });
  const response = await fetch(`/api/sisyphus/approvals/pending?${params.toString()}`);
  const body = await handleJson(response);
  
  // Return null if no approval, otherwise create ApprovalRequest instance
  if (!body.approval) {
    return null;
  }
  
  return ApprovalRequest.fromJSON(body.approval);
}

/**
 * Get approval status by request ID
 * @param {string} requestId - Request ID
 * @returns {Promise<ApprovalRequest>} ApprovalRequest instance
 * @throws {Error} If requestId is invalid or approval not found
 */
export async function getApprovalStatus(requestId) {
  if (!requestId || typeof requestId !== "string") {
    throw new Error("requestId must be a non-empty string");
  }

  const response = await fetch(`/api/sisyphus/approvals/${requestId}`);
  const body = await handleJson(response);
  
  if (!body.approval) {
    throw new Error(`Approval not found: ${requestId}`);
  }
  
  return ApprovalRequest.fromJSON(body.approval);
}

/**
 * Approve an approval request
 * @param {string} requestId - Request ID
 * @param {string} resolvedBy - Who is approving (default: "user")
 * @returns {Promise<ApprovalRequest>} Updated ApprovalRequest instance
 * @throws {Error} If parameters are invalid
 */
export async function approveRequest(requestId, resolvedBy = "user") {
  if (!requestId || typeof requestId !== "string") {
    throw new Error("requestId must be a non-empty string");
  }
  if (!resolvedBy || typeof resolvedBy !== "string") {
    throw new Error("resolvedBy must be a non-empty string");
  }

  const response = await fetch(`/api/sisyphus/approvals/${requestId}/approve`, {
    method: "POST",
    headers: jsonHeaders,
    body: JSON.stringify({ resolved_by: resolvedBy })
  });
  const body = await handleJson(response);
  
  if (!body.approval) {
    throw new Error(`Failed to approve request: ${requestId}`);
  }
  
  return ApprovalRequest.fromJSON(body.approval);
}

/**
 * Reject an approval request
 * @param {string} requestId - Request ID
 * @param {string} resolvedBy - Who is rejecting (default: "user")
 * @returns {Promise<ApprovalRequest>} Updated ApprovalRequest instance
 * @throws {Error} If parameters are invalid
 */
export async function rejectRequest(requestId, resolvedBy = "user") {
  if (!requestId || typeof requestId !== "string") {
    throw new Error("requestId must be a non-empty string");
  }
  if (!resolvedBy || typeof resolvedBy !== "string") {
    throw new Error("resolvedBy must be a non-empty string");
  }

  const response = await fetch(`/api/sisyphus/approvals/${requestId}/reject`, {
    method: "POST",
    headers: jsonHeaders,
    body: JSON.stringify({ resolved_by: resolvedBy })
  });
  const body = await handleJson(response);
  
  if (!body.approval) {
    throw new Error(`Failed to reject request: ${requestId}`);
  }
  
  return ApprovalRequest.fromJSON(body.approval);
}

/**
 * Subscribe to real-time progress updates for a Sisyphus execution via SSE
 * 
 * Note: This is a convenience wrapper around the general workerProgressStream utility.
 * For more advanced usage, import subscribeToWorkerProgress from utils/workerProgressStream.js
 * 
 * @param {string} executionId - The execution ID to monitor
 * @param {Object} callbacks - Event callbacks
 * @param {Function} callbacks.onEvent - Called for each progress event
 * @param {Function} callbacks.onError - Called on error
 * @param {Function} callbacks.onComplete - Called when stream closes
 * @returns {EventSource} The EventSource object (call .close() to unsubscribe)
 */
export function subscribeToExecutionProgress(executionId, { onEvent, onError, onComplete }) {
  // This can be replaced with import from workerProgressStream.js in the future
  // For now, keeping simple implementation for backward compatibility
  const eventSource = new EventSource(`/api/sisyphus/executions/${executionId}/stream`);

  // Handle connection
  eventSource.addEventListener("connected", (event) => {
    const data = JSON.parse(event.data);
    console.log("SSE connected:", data);
  });

  // Handle all progress events
  const eventTypes = [
    "started",
    "milestone_started",
    "milestone_completed",
    "step_started",
    "step_completed",
    "step_failed",
    "file_changed",
    "checkpoint_created",
    "completed",
    "failed",
    "cancelled"
  ];

  eventTypes.forEach((eventType) => {
    eventSource.addEventListener(eventType, (event) => {
      const data = JSON.parse(event.data);
      if (onEvent) {
        onEvent({ ...data, event_type: eventType });
      }

      // Close on terminal events
      if (["completed", "failed", "cancelled"].includes(eventType)) {
        eventSource.close();
        if (onComplete) {
          onComplete(data);
        }
      }
    });
  });

  // Handle errors
  eventSource.onerror = (error) => {
    console.error("SSE error:", error);
    if (onError) {
      onError(error);
    }
    eventSource.close();
  };

  return eventSource;
}

