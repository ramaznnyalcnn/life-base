import { apiRequest } from "./client";

export function fetchPushConfig() {
  return apiRequest("/notifications/config");
}

export function createPushSubscription(payload) {
  return apiRequest("/notifications/subscriptions", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}

export function deletePushSubscription(endpoint) {
  return apiRequest("/notifications/subscriptions", {
    method: "DELETE",
    body: JSON.stringify({ endpoint })
  });
}

export function sendTestNotification(payload) {
  return apiRequest("/notifications/test", {
    method: "POST",
    body: JSON.stringify(payload)
  });
}
