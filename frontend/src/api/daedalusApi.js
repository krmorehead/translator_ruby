const API_BASE = '';

export const daedalusApi = {
  createPlan: async ({ goal, path, context }) => {
    const response = await fetch(`${API_BASE}/daedalus/create`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ goal, path, context }),
    });

    const data = await response.json();
    
    if (!response.ok) {
      throw new Error(data.error);
    }

    return data;
  },
};

