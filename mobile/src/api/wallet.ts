import { apiRequest } from "./client";
import type { ApiContext } from "./client";
import type { CardStatementSummary, WalletSummary } from "./types";

export function fetchWalletSummary(context: ApiContext) {
  return apiRequest<WalletSummary>(context, "/wallet/summary");
}

export function fetchCardStatements(context: ApiContext) {
  return apiRequest<CardStatementSummary[]>(context, "/wallet/statements");
}
