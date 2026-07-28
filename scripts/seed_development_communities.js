#!/usr/bin/env node

"use strict";

/**
 * 本番の公開コミュニティ設定だけを開発Firebaseへ複製する。
 *
 * 安全上の制約:
 * - コピー元・コピー先プロジェクトIDは固定
 * - communitySurfingVisible == true の組織だけが対象
 * - 会員・管理者・申請・投稿などのサブコレクションは対象外
 * - 公開参加に必要なフィールドだけを許可リスト方式でコピー
 * - コピー先に既存文書がある場合は上書きしない
 * - --apply を付けない限り書き込まない
 */

const SOURCE_PROJECT_ID = "ictnagaoka-member";
const TARGET_PROJECT_ID = "kome-org-portal-next-dev";
const DATABASE_ID = "(default)";

const FIREBASE_TOOLS_ROOT = "/usr/local/lib/node_modules/firebase-tools/lib";
const firebaseAuth = require(`${FIREBASE_TOOLS_ROOT}/auth.js`);

const ALLOWED_FIELDS = [
  "name",
  "displayName",
  "organizationCode",
  "description",
  "isActive",
  "communityJoinEnabled",
  "communitySurfingVisible",
  "homepageURL",
  "logoDisplayHeight",
  "logoImageURL",
  "createdAt",
  "updatedAt",
];

const APPLY = process.argv.includes("--apply");

function databaseRoot(projectId) {
  return `https://firestore.googleapis.com/v1/projects/${projectId}/databases/${encodeURIComponent(
    DATABASE_ID,
  )}/documents`;
}

async function readPublicOrganizations() {
  const response = await fetch(`${databaseRoot(SOURCE_PROJECT_ID)}:runQuery`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId: "organizations" }],
        where: {
          fieldFilter: {
            field: { fieldPath: "communitySurfingVisible" },
            op: "EQUAL",
            value: { booleanValue: true },
          },
        },
      },
    }),
  });

  if (!response.ok) {
    throw new Error(
      `公開コミュニティの取得に失敗しました (${response.status})`,
    );
  }

  const rows = await response.json();
  return rows
    .filter((row) => row.document)
    .map((row) => {
      const documentId = row.document.name.split("/").at(-1);
      const sourceFields = row.document.fields ?? {};
      const fields = {};

      for (const fieldName of ALLOWED_FIELDS) {
        if (sourceFields[fieldName] !== undefined) {
          fields[fieldName] = sourceFields[fieldName];
        }
      }

      return { documentId, fields };
    })
    .filter(({ fields }) => {
      return (
        fields.organizationCode?.stringValue &&
        fields.name?.stringValue &&
        fields.isActive?.booleanValue === true &&
        fields.communityJoinEnabled?.booleanValue === true
      );
    });
}

async function accessToken() {
  const account = firebaseAuth.getGlobalDefaultAccount();
  if (!account?.tokens?.refresh_token) {
    throw new Error(
      "Firebase CLIへログインしていません。firebase login を実行してください。",
    );
  }

  const token = await firebaseAuth.getAccessToken(
    account.tokens.refresh_token,
    [],
  );
  if (!token?.access_token) {
    throw new Error("Firebase CLIのアクセストークンを取得できませんでした。");
  }
  return token.access_token;
}

async function targetDocumentExists(documentId, token) {
  const response = await fetch(
    `${databaseRoot(TARGET_PROJECT_ID)}/organizations/${encodeURIComponent(
      documentId,
    )}`,
    { headers: { authorization: `Bearer ${token}` } },
  );

  if (response.status === 404) {
    return false;
  }
  if (!response.ok) {
    throw new Error(
      `開発コミュニティ ${documentId} の確認に失敗しました (${response.status})`,
    );
  }
  return true;
}

async function createTargetDocument({ documentId, fields }, token) {
  const response = await fetch(
    `${databaseRoot(TARGET_PROJECT_ID)}/organizations/${encodeURIComponent(
      documentId,
    )}`,
    {
      method: "PATCH",
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ fields }),
    },
  );

  if (!response.ok) {
    const detail = await response.text();
    throw new Error(
      `開発コミュニティ ${documentId} の作成に失敗しました (${response.status}): ${detail}`,
    );
  }
}

async function main() {
  const organizations = await readPublicOrganizations();
  if (organizations.length === 0) {
    throw new Error("複製可能な公開・参加受付中コミュニティがありません。");
  }

  console.log(
    `${APPLY ? "投入" : "確認"}対象: ${organizations
      .map(({ documentId }) => documentId)
      .join(", ")}`,
  );

  if (!APPLY) {
    console.log(
      `書き込みは行っていません。${TARGET_PROJECT_ID}へ投入するには --apply を付けて再実行してください。`,
    );
    return;
  }

  const token = await accessToken();
  let createdCount = 0;
  let skippedCount = 0;

  for (const organization of organizations) {
    if (await targetDocumentExists(organization.documentId, token)) {
      console.log(`既存のためスキップ: ${organization.documentId}`);
      skippedCount += 1;
      continue;
    }

    await createTargetDocument(organization, token);
    console.log(`作成: ${organization.documentId}`);
    createdCount += 1;
  }

  console.log(
    `完了: 作成 ${createdCount}件、既存のためスキップ ${skippedCount}件`,
  );
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
