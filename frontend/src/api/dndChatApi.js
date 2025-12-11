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

export async function sendMessage(message) {
  const response = await fetch("/dnd_chat/messages", {
    method: "POST",
    headers: jsonHeaders,
    body: JSON.stringify({ message })
  });
  return handleJson(response);
}

export async function getConversation() {
  const response = await fetch("/dnd_chat/messages");
  return handleJson(response);
}

export async function getAgentState() {
  const response = await fetch("/dnd_chat/agent");
  return handleJson(response);
}

export async function getAgentVersion() {
  const response = await fetch("/dnd_chat/agent/version");
  return handleJson(response);
}

export async function getMessagesContract() {
  const response = await fetch("/dnd_chat/messages/contract");
  return response.text();
}

export async function getAgentContract() {
  const response = await fetch("/dnd_chat/agent/contract");
  return response.text();
}


