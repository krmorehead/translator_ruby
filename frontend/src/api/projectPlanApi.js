const jsonHeaders = { "Content-Type": "application/json" };

async function handleJson(response) {
  const body = await response.json();
  if (!response.ok) {
    throw new Error(body.error);
  }
  return body;
}

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

export async function getProjectPlanStatus(id) {
  const response = await fetch(`/project_planning/status/${id}`);
  return handleJson(response);
}

