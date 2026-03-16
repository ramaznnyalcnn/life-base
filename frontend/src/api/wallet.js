import { apiRequest } from "./client";

export function fetchWalletSummary() {
  return apiRequest("/wallet/summary");
}

export function fetchCardStatements() {
  return apiRequest("/wallet/statements");
}
