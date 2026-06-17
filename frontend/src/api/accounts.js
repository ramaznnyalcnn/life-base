import { apiRequest } from "./client";

export function fetchAccounts() {
  return apiRequest("/accounts");
}

export function createAccount(payload) {
  return apiRequest("/accounts", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function updateAccount(accountId, payload) {
  return apiRequest(`/accounts/${accountId}`, {
    method: "PUT",
    body: JSON.stringify(payload)
  });
}
