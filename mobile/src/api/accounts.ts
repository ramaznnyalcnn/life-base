import { apiRequest } from "./client";
import type { ApiContext } from "./client";
import type { Account, AccountType } from "./types";

export type AccountPayload = {
  name?: string;
  type?: AccountType;
  currency?: string;
  balance?: string;
  credit_limit?: string | null;
  statement_day?: number | null;
  due_day?: number | null;
  issuer?: string | null;
  is_active?: boolean;
};

export function fetchAccounts(context: ApiContext) {
  return apiRequest<Account[]>(context, "/accounts");
}

export function createAccount(context: ApiContext, payload: AccountPayload) {
  return apiRequest<Account>(context, "/accounts", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function updateAccount(context: ApiContext, accountId: number, payload: AccountPayload) {
  return apiRequest<Account>(context, `/accounts/${accountId}`, {
    method: "PUT",
    body: JSON.stringify(payload)
  });
}
