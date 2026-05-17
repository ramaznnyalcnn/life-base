import { apiRequest } from "./client";
import type { ApiContext } from "./client";
import type { AIExecutionResponse } from "./types";

export function executeAI(context: ApiContext, message: string) {
  return apiRequest<AIExecutionResponse>(context, "/ai/execute", {
    method: "POST",
    body: JSON.stringify({ message })
  });
}

export function clarifyAI(context: ApiContext, originalMessage: string, clarification: string) {
  return apiRequest<AIExecutionResponse>(context, "/ai/clarify", {
    method: "POST",
    body: JSON.stringify({
      original_message: originalMessage,
      clarification
    })
  });
}
