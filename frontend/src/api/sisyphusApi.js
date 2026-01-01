const jsonHeaders = { "Content-Type": "application/json" };

async function handleJson(response) {
  const contentType = response.headers.get("content-type") || "";
  const body = contentType.includes("application/json") ? await response.json() : await response.text();
  if (!response.ok) {
    const errorMessage = body?.error || response.statusText || "Request failed";
    throw new Error(errorMessage);
  }
  return body;
}

// Execution Management

/**
 * Start a new Sisyphus execution
 * @param {Object} params - Execution parameters
 * @param {string} params.planPath - Path to the execution plan markdown file
 * @param {string} params.projectPath - Path to the project/codebase
 * @param {Object} params.options - Additional execution options
 * @returns {Promise<Object>} Execution result with execution_id and state
 */
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

/**
 * Get execution state
 * @param {string} executionId - Execution identifier
 * @returns {Promise<Object>} Execution state
 */
export async function getExecutionState(executionId) {
  const response = await fetch(`/api/sisyphus/executions/${executionId}`);
  return handleJson(response);
}

/**
 * List recent executions
 * @param {number} limit - Maximum number of executions to return
 * @returns {Promise<Object>} List of executions
 */
export async function listExecutions(limit = 50) {
  const response = await fetch(`/api/sisyphus/executions?limit=${limit}`);
  return handleJson(response);
}

/**
 * Cancel an executing running execution
 * @param {string} executionId - Execution identifier
 * @returns {Promise<Object>} Cancellation result
 */
export async function cancelExecution(executionId) {
  const response = await fetch(`/api/sisyphus/executions/${executionId}`, {
    method: "DELETE"
  });
  return handleJson(response);
}

// File System Operations

/**
 * Get directory tree
 * @param {Object} params - Tree parameters
 * @param {string} params.path - Directory path to list
 * @param {number} params.maxDepth - Maximum depth to traverse
 * @param {Array<string>} params.extensions - File extensions to filter
 * @param {Array<string>} params.ignorePatterns - Patterns to ignore
 * @returns {Promise<Object>} Directory tree structure
 */
export async function getFileTree({ path, maxDepth, extensions, ignorePatterns }) {
  const params = new URLSearchParams();
  params.append("path", path);
  if (maxDepth !== undefined) params.append("max_depth", maxDepth);
  if (extensions) params.append("extensions", JSON.stringify(extensions));
  if (ignorePatterns) params.append("ignore_patterns", JSON.stringify(ignorePatterns));

  const response = await fetch(`/api/sisyphus/filesystem/tree?${params.toString()}`);
  return handleJson(response);
}

/**
 * Read file contents
 * @param {string} path - File path to read
 * @returns {Promise<Object>} File contents
 */
export async function readFile(path) {
  const params = new URLSearchParams({ path });
  const response = await fetch(`/api/sisyphus/filesystem/read?${params.toString()}`);
  return handleJson(response);
}

/**
 * Search files
 * @param {Object} params - Search parameters
 * @param {string} params.pattern - Regex pattern to search for
 * @param {string} params.path - Directory path to search in
 * @param {Array<string>} params.extensions - File extensions to search
 * @param {number} params.maxResults - Maximum number of results
 * @param {boolean} params.caseInsensitive - Case insensitive search
 * @param {boolean} params.wholeWord - Whole word matching
 * @param {number} params.contextLines - Context lines to include
 * @returns {Promise<Object>} Search results
 */
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

// Configuration Management

/**
 * Get current agent configuration
 * @returns {Promise<Object>} Current configuration
 */
export async function getConfig() {
  const response = await fetch("/api/sisyphus/config");
  return handleJson(response);
}

/**
 * Validate a capability configuration
 * @param {Object} capability - Capability configuration
 * @param {string} capability.name - Capability name
 * @param {string} capability.modelName - Model name
 * @param {number} capability.port - Port number
 * @param {number} capability.maxContext - Max context size
 * @param {string} capability.baseUrl - Base URL
 * @returns {Promise<Object>} Validation result
 */
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

/**
 * Test connection to an LLM capability
 * @param {string} capabilityName - Name of the capability to test
 * @returns {Promise<Object>} Test result
 */
export async function testConnection(capabilityName) {
  const response = await fetch("/api/sisyphus/config/test", {
    method: "POST",
    headers: jsonHeaders,
    body: JSON.stringify({ capability_name: capabilityName })
  });
  return handleJson(response);
}

