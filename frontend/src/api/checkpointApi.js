// API client for Git Checkpoint Management
// Provides methods to interact with checkpoint endpoints

const BASE_URL = '/api/v1/checkpoints';

/**
 * Create a new checkpoint
 * @param {string} path - Repository path
 * @param {string} message - Checkpoint message
 * @param {object} metadata - Optional metadata (execution_id, milestone_id, workflow_id, is_backup)
 * @returns {Promise<object>} Created checkpoint
 */
export async function createCheckpoint(path, message, metadata = {}) {
  const response = await fetch(BASE_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      path,
      message,
      metadata,
    }),
  });

  const data = await response.json();
  
  if (!response.ok) {
    throw new Error(data.error || 'Failed to create checkpoint');
  }

  return data;
}

/**
 * List checkpoints with optional filtering
 * @param {string} path - Repository path
 * @param {object} options - Filter options (limit, execution_id, milestone_id, workflow_id, is_backup)
 * @returns {Promise<object>} List of checkpoints
 */
export async function listCheckpoints(path, options = {}) {
  const params = new URLSearchParams({ path, ...options });
  const response = await fetch(`${BASE_URL}?${params}`);
  
  const data = await response.json();
  
  if (!response.ok) {
    throw new Error(data.error || 'Failed to list checkpoints');
  }

  return data;
}

/**
 * Get a specific checkpoint by ID
 * @param {string} checkpointId - Checkpoint ID
 * @param {string} path - Repository path
 * @returns {Promise<object>} Checkpoint details
 */
export async function getCheckpoint(checkpointId, path) {
  const params = new URLSearchParams({ path });
  const response = await fetch(`${BASE_URL}/${checkpointId}?${params}`);
  
  const data = await response.json();
  
  if (!response.ok) {
    throw new Error(data.error || 'Failed to get checkpoint');
  }

  return data;
}

/**
 * Get diff between checkpoints
 * @param {string} checkpointId - Source checkpoint ID
 * @param {string} path - Repository path
 * @param {string} targetCheckpointId - Target checkpoint ID (optional, defaults to current)
 * @returns {Promise<object>} Diff information
 */
export async function getCheckpointDiff(checkpointId, path, targetCheckpointId = null) {
  const params = new URLSearchParams({ path });
  if (targetCheckpointId) {
    params.append('target_checkpoint_id', targetCheckpointId);
  }
  
  const response = await fetch(`${BASE_URL}/${checkpointId}/diff?${params}`);
  
  const data = await response.json();
  
  if (!response.ok) {
    throw new Error(data.error || 'Failed to get checkpoint diff');
  }

  return data;
}

/**
 * Rollback to a specific checkpoint
 * @param {string} checkpointId - Checkpoint ID to rollback to
 * @param {string} path - Repository path
 * @param {boolean} force - Force rollback even if there are uncommitted changes
 * @returns {Promise<object>} Rollback result
 */
export async function rollbackToCheckpoint(checkpointId, path, force = false) {
  const response = await fetch(`${BASE_URL}/${checkpointId}/rollback`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      path,
      force,
    }),
  });

  const data = await response.json();
  
  if (!response.ok) {
    throw new Error(data.error || 'Failed to rollback checkpoint');
  }

  return data;
}

/**
 * Get list of rollback candidates
 * @param {string} path - Repository path
 * @param {number} limit - Maximum number of candidates to return
 * @returns {Promise<object>} List of rollback candidates
 */
export async function getRollbackCandidates(path, limit = null) {
  const params = new URLSearchParams({ path });
  if (limit) {
    params.append('limit', limit);
  }
  
  const response = await fetch(`${BASE_URL}/candidates?${params}`);
  
  const data = await response.json();
  
  if (!response.ok) {
    throw new Error(data.error || 'Failed to get rollback candidates');
  }

  return data;
}

/**
 * Get current checkpoint ID
 * @param {string} path - Repository path
 * @returns {Promise<object>} Current checkpoint ID
 */
export async function getCurrentCheckpoint(path) {
  const params = new URLSearchParams({ path });
  const response = await fetch(`${BASE_URL}/current?${params}`);
  
  const data = await response.json();
  
  if (!response.ok) {
    throw new Error(data.error || 'Failed to get current checkpoint');
  }

  return data;
}

