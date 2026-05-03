import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

/**
 * 簡易暗号化（Base64）
 * ※本番強化するなら Secret Manager + crypto 推奨
 */
function encrypt(text: string): string {
  return Buffer.from(text, "utf-8").toString("base64");
}

function decrypt(text: string): string {
  return Buffer.from(text, "base64").toString("utf-8");
}

/**
 * ■ Vimeo設定保存（管理アプリ → Functions）
 * organizations/{orgId}/private/settings/vimeo
 */
export const saveVimeoConfig = functions
  .region("asia-northeast1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "ログイン必須");
    }

    const { organizationId, accessToken, userId } = data;

    if (!organizationId || !accessToken) {
      throw new functions.https.HttpsError("invalid-argument", "パラメータ不足");
    }

    const encryptedToken = encrypt(accessToken);

    await db
      .collection("organizations")
      .doc(organizationId)
      .collection("private")
      .doc("settings")
      .set({
        vimeo: {
          accessToken: encryptedToken,
          userId: userId || "",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      }, { merge: true });

    return { success: true };
  });

/**
 * ■ Vimeo取得（動画取得時に使用）
 */
export const getVimeoConfig = functions
  .region("asia-northeast1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "ログイン必須");
    }

    const { organizationId } = data;

    const doc = await db
      .collection("organizations")
      .doc(organizationId)
      .collection("private")
      .doc("settings")
      .get();

    const vimeo = doc.data()?.vimeo;

    if (!vimeo) {
      return { exists: false };
    }

    return {
      exists: true,
      accessToken: decrypt(vimeo.accessToken),
      userId: vimeo.userId,
    };
  });

/**
 * ■ メッセージ送信トリガー（通知）
 * organizations/{orgId}/messages/{messageId}
 */
export const onMessageCreated = functions
  .region("asia-northeast1")
  .firestore.document("organizations/{orgId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const orgId = context.params.orgId;

    const title = data.title || "お知らせ";
    const body = data.body || "";

    const isBroadcast = data.isBroadcast ?? true;
    const categoryTargets: string[] = data.categoryTargets || [];
    const targetUids: string[] = data.targetMemberUids || [];

    // 会員取得
    const membersSnap = await db
      .collection("organizations")
      .doc(orgId)
      .collection("members")
      .get();

    const tokens: string[] = [];

    membersSnap.forEach((doc) => {
      const m = doc.data();

      if (!m.fcmToken) return;

      // 個別指定
      if (targetUids.length > 0) {
        if (targetUids.includes(doc.id)) {
          tokens.push(m.fcmToken);
        }
        return;
      }

      // カテゴリ指定
      if (categoryTargets.length > 0) {
        if (categoryTargets.includes(m.category)) {
          tokens.push(m.fcmToken);
        }
        return;
      }

      // 全体配信
      if (isBroadcast) {
        tokens.push(m.fcmToken);
      }
    });

    if (tokens.length === 0) {
      console.log("送信対象なし");
      return;
    }

    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title,
        body,
      },
      data: {
        messageId: snap.id,
        type: "message",
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

console.log("通知送信結果:", {
  targetCount: tokens.length,
  successCount: response.successCount,
  failureCount: response.failureCount,
});

response.responses.forEach((r, index) => {
  if (!r.success) {
    console.error("通知送信失敗:", {
      index,
      errorCode: r.error?.code,
      errorMessage: r.error?.message,
      tokenPrefix: tokens[index]?.substring(0, 20),
    });
  }
});
  });

/**
 * ■ 会員登録時（オプション）
 * 初期データ補完などに使える
 */
export const onMemberCreated = functions
  .region("asia-northeast1")
  .firestore.document("organizations/{orgId}/members/{uid}")
  .onCreate(async (snap, context) => {
    const data = snap.data();

    console.log("新規会員:", data.name || "no-name");
  });
