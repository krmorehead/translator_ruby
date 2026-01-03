const jsonHeaders = { "Content-Type": "application/json" };

async function handleJson(response) {
  const body = await response.json();
  if (!response.ok) {
    throw new Error(body.error);
  }
  return body;
}

export const daedalusApi = {
  async createPlan({ goal, path, context }) {
    const response = await fetch("/daedalus/create", {
      method: "POST",
      headers: jsonHeaders,
      body: JSON.stringify({
        goal,
        path,
        context
      })
    });
    return handleJson(response);
  },

  async getPlan(planId) {
    const response = await fetch(`/api/daedalus/plans/${planId}`);
    return handleJson(response);
  },

  async listPlans(limit = 50) {
    const response = await fetch(`/api/daedalus/plans?limit=${limit}`);
    return handleJson(response);
  },

  async cancelPlan(planId) {
    const response = await fetch(`/api/daedalus/plans/${planId}`, {
      method: "DELETE"
    });
    return handleJson(response);
  }
};








