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

/**
 * Create a project plan
 * @param {Object} params - Planning parameters
 * @param {string} params.goal - The project goal/feature to plan
 * @param {string} params.path - Path to the target codebase
 * @param {string} params.projectName - Name for the project
 * @param {Object} params.context - Optional context (known_files, constraints)
 * @returns {Promise<Object>} Planning result
 */
export async function createProjectPlan({ goal, path, projectName, context = {} }) {
  const response = await fetch("/project_planning/create", {
    method: "POST",
    headers: jsonHeaders,
    body: JSON.stringify({
      goal,
      path,
      project_name: projectName,
      context
    })
  });
  return handleJson(response);
}

/**
 * Get project plan status (for future async support)
 * @param {string} id - Plan ID
 * @returns {Promise<Object>} Status result
 */
export async function getProjectPlanStatus(id) {
  const response = await fetch(`/project_planning/status/${id}`);
  return handleJson(response);
}

