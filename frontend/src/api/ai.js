import { apiRequest } from "./client";

export function executeAI(message) {
  return apiRequest("/ai/execute", {
    method: "POST",
    body: JSON.stringify({ message })
  });
}

export function clarifyAI(originalMessage, clarification) {
  return apiRequest("/ai/clarify", {
    method: "POST",
    body: JSON.stringify({
      original_message: originalMessage,
      clarification
    })
  });
}
