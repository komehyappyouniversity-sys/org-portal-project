import assert from "node:assert/strict";

const projectId = "demo-org-portal-next";
const authBase = "http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1";
const firestoreBase = `http://127.0.0.1:8080/v1/projects/${projectId}/databases/(default)/documents`;

async function signUp(email) {
  const response = await fetch(`${authBase}/accounts:signUp?key=fake-api-key`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email, password: "test-password", returnSecureToken: true }),
  });
  assert.equal(response.status, 200, await response.text());
  return response.json();
}

async function firestoreRequest(path, token, method = "GET", fields) {
  return fetch(`${firestoreBase}/${path}`, {
    method,
    headers: {
      authorization: `Bearer ${token}`,
      ...(fields ? { "content-type": "application/json" } : {}),
    },
    body: fields ? JSON.stringify({ fields }) : undefined,
  });
}

function usageFields(uid) {
  return {
    id: { stringValue: "log-1" },
    userId: { stringValue: uid },
    eventType: { stringValue: "video_position" },
    targetId: { stringValue: "video-1" },
    positionSeconds: { doubleValue: 30 },
    occurredAt: { timestampValue: "2026-08-15T00:00:00Z" },
    expiresAt: { timestampValue: "2026-11-13T00:00:00Z" },
  };
}

const owner = await signUp("usage-owner@example.test");
const other = await signUp("usage-other@example.test");
const path = `memberPrivate/${owner.localId}/usageLogs/log-1`;

let response = await firestoreRequest(path, owner.idToken, "PATCH", usageFields(owner.localId));
assert.equal(response.status, 200, await response.text());

response = await firestoreRequest(path, owner.idToken);
assert.equal(response.status, 200, await response.text());

response = await firestoreRequest(path, other.idToken);
assert.equal(response.status, 403, "another user must not read an owner's UsageLog");

response = await firestoreRequest(path, other.idToken, "PATCH", usageFields(owner.localId));
assert.equal(response.status, 403, "another user must not write an owner's UsageLog");

response = await firestoreRequest(path, owner.idToken, "DELETE");
assert.equal(response.status, 200, await response.text());

console.log("UsageLog rules: owner access allowed; cross-user access denied.");
