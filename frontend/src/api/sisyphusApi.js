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

