const assert = require("node:assert/strict");

const projectId = process.env.GCLOUD_PROJECT || "demo-org-portal-next";
const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST || "127.0.0.1:9099";
const firestoreBase = `http://${firestoreHost}/v1/projects/${projectId}/databases/(default)`;

async function request(url, options = {}, expectedStatus = 200) {
  const response = await fetch(url, options);
  const text = await response.text();
  assert.equal(
    response.status,
    expectedStatus,
    `${options.method || "GET"} ${url} returned ${response.status}: ${text}`,
  );
  return text ? JSON.parse(text) : {};
}

function fields({ title, body, sortOrder, isPublished }) {
  return {
    title: { stringValue: title },
    body: { stringValue: body },
    sortOrder: { integerValue: String(sortOrder) },
    imageUrls: { arrayValue: { values: [] } },
    pdfUrl: { stringValue: "" },
    externalUrl: { stringValue: "" },
    isPublished: { booleanValue: isPublished },
  };
}

async function seed(path, documentFields) {
  await request(
    `${firestoreBase}/documents/${path}`,
    {
      method: "PATCH",
      headers: {
        Authorization: "Bearer owner",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ fields: documentFields }),
    },
  );
}

async function publishedQuery(parentPath, collectionId, token) {
  const suffix = parentPath
    ? `/documents/${parentPath}:runQuery`
    : "/documents:runQuery";
  const headers = { "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  return request(`${firestoreBase}${suffix}`, {
    method: "POST",
    headers,
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId }],
        where: {
          fieldFilter: {
            field: { fieldPath: "isPublished" },
            op: "EQUAL",
            value: { booleanValue: true },
          },
        },
      },
    }),
  });
}

async function main() {
  const email = `manual-member-${Date.now()}@example.com`;
  const auth = await request(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake-api-key`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password: "password123", returnSecureToken: true }),
    },
  );
  const uid = auth.localId;
  const token = auth.idToken;

  await seed("sharedManuals/shared-published", fields({
    title: "共通公開", body: "本文", sortOrder: 2, isPublished: true,
  }));
  await seed("sharedManuals/shared-draft", fields({
    title: "共通下書き", body: "本文", sortOrder: 1, isPublished: false,
  }));
  await seed("organizations/org-manual-test", {
    name: { stringValue: "Manual Test" },
    isActive: { booleanValue: true },
  });
  await seed(`organizations/org-manual-test/members/${uid}`, {
    uid: { stringValue: uid },
    userId: { stringValue: uid },
    organizationId: { stringValue: "org-manual-test" },
    communityId: { stringValue: "org-manual-test" },
    role: { stringValue: "member" },
    status: { stringValue: "approved" },
  });
  await seed("organizations/org-manual-test/manuals/community-published", fields({
    title: "専用公開", body: "本文", sortOrder: 1, isPublished: true,
  }));
  await seed("organizations/org-manual-test/manuals/community-draft", fields({
    title: "専用下書き", body: "本文", sortOrder: 0, isPublished: false,
  }));

  const sharedRows = await publishedQuery(null, "sharedManuals", null);
  const sharedIds = sharedRows
    .filter((row) => row.document)
    .map((row) => row.document.name.split("/").at(-1));
  assert.deepEqual(sharedIds, ["shared-published"]);
  await request(
    `${firestoreBase}/documents/sharedManuals/shared-draft`,
    {},
    403,
  );

  await request(
    `${firestoreBase}/documents/organizations/org-manual-test:runQuery`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: "manuals" }],
          where: {
            fieldFilter: {
              field: { fieldPath: "isPublished" },
              op: "EQUAL",
              value: { booleanValue: true },
            },
          },
        },
      }),
    },
    403,
  );

  const communityRows = await publishedQuery(
    "organizations/org-manual-test",
    "manuals",
    token,
  );
  const communityIds = communityRows
    .filter((row) => row.document)
    .map((row) => row.document.name.split("/").at(-1));
  assert.deepEqual(communityIds, ["community-published"]);
  await request(
    `${firestoreBase}/documents/organizations/org-manual-test/manuals/community-draft`,
    { headers: { Authorization: `Bearer ${token}` } },
    403,
  );

  process.stdout.write("Manual Firestore emulator test passed.\n");
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
