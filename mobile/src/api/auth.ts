import { apiRequest } from "./client";
import type { ApiContext } from "./client";
import type { AuthSessionRead, User } from "./types";

export function login(context: ApiContext, payload: { email: string; password: string }) {
  return apiRequest<AuthSessionRead>(context, "/auth/login", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function fetchCurrentUser(context: ApiContext) {
  return apiRequest<User>(context, "/auth/me");
}
