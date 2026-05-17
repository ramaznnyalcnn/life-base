import { apiRequest } from "./client";
import type { ApiContext } from "./client";
import type { Transaction, TransactionType } from "./types";

export type TransactionPayload = {
  account_id?: number;
  category_name?: string | null;
  type?: TransactionType;
  amount?: string;
  description?: string;
  note?: string | null;
  occurred_at?: string;
};

export type TransactionFilters = {
  accountId?: number | null;
  type?: TransactionType | "";
  search?: string;
};

export function createTransaction(context: ApiContext, payload: TransactionPayload) {
  return apiRequest<Transaction>(context, "/transactions", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function fetchTransactions(context: ApiContext, filters: TransactionFilters = {}) {
  const params = new URLSearchParams();
  if (filters.accountId) {
    params.set("account_id", String(filters.accountId));
  }
  if (filters.type) {
    params.set("type", filters.type);
  }
  if (filters.search?.trim()) {
    params.set("search", filters.search.trim());
  }
  const query = params.toString();
  return apiRequest<Transaction[]>(context, query ? `/transactions?${query}` : "/transactions");
}

export function updateTransaction(
  context: ApiContext,
  transactionId: number,
  payload: TransactionPayload
) {
  return apiRequest<Transaction>(context, `/transactions/${transactionId}`, {
    method: "PUT",
    body: JSON.stringify(payload)
  });
}

export function deleteTransaction(context: ApiContext, transactionId: number) {
  return apiRequest<void>(context, `/transactions/${transactionId}`, {
    method: "DELETE"
  });
}
