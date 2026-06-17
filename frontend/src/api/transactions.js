import { apiRequest } from "./client";

export function createTransaction(payload) {
  return apiRequest("/transactions", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function fetchTransactions(filters = {}) {
  const search = new URLSearchParams();

  if (filters.accountId) {
    search.set("account_id", String(filters.accountId));
  }
  if (filters.type) {
    search.set("type", filters.type);
  }
  if (filters.search) {
    search.set("search", filters.search.trim());
  }

  const query = search.toString();
  return apiRequest(query ? `/transactions?${query}` : "/transactions");
}

export function updateTransaction(transactionId, payload) {
  return apiRequest(`/transactions/${transactionId}`, {
    method: "PUT",
    body: JSON.stringify(payload)
  });
}

export function deleteTransaction(transactionId) {
  return apiRequest(`/transactions/${transactionId}`, {
    method: "DELETE"
  });
}
