import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import axios from "axios";
import * as crypto from "crypto";

admin.initializeApp();

const db = admin.firestore();
const REGION = "asia-northeast1";

// functions:config:get に入っている encryption_key を使用
function getEncryptionKey(): Buffer {
  const key =
    process.env.VIMEO_ENCRYPTION_KEY ||
    functions.config().vimeo?.encryption_key;

  if (!key) {
    throw new Error("VIMEO_ENCRYPTION_KEY is not set");
  }

  return Buffer.from(key, "base64");
}

function encryptText(text: string): string {
  const key = getEncryptionKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", key, iv);

  const encrypted = Buffer.concat([
    cipher.update(text, "utf8"),
    cipher.final(),
  ]);

  const tag = cipher.getAuthTag();

  return JSON.stringify({
    iv: iv.toString("base64"),
    tag: tag.toString("base64"),
    data: encrypted.toString("base64"),
  });
}

function decryptText(payload: string): string {
  const key = getEncryptionKey();
  const parsed = JSON.parse(payload);

  const iv = Buffer.from(parsed.iv, "base64");
  const tag = Buffer.from(parsed.tag, "base64");
  const encrypted = Buffer.from(parsed.data, "base64");

  const decipher = crypto.createDecipheriv("aes-256-gcm", key, iv);
  decipher.setAuthTag(tag);

  return Buffer.concat([
    decipher.update(encrypted),
    decipher.final(),
  ]).toString("utf8");
}

async function assertAdmin(organizationId: string, uid: string): Promise<void> {
  const adminDoc = await db
    .collection("organizations")
    .doc(organizationId)
    .collection("admins")
    .doc(uid)
    .get();

  if (!adminDoc.exists || adminDoc.data()?.isActive !== true) {
    throw new Error("permission-denied");
  }
}

async function getUidFromRequest(req: functions.https.Request): Promise<string> {
  const authorization = req.headers.authorization || "";

  if (!authorization.startsWith("Bearer ")) {
    throw new Error("missing-auth-token");
  }

  const idToken = authorization.replace("Bearer ", "");
  const decoded = await admin.auth().verifyIdToken(idToken);

  return decoded.uid;
}

// MARK: - Vimeo設定保存

export const saveVimeoConfigHttp = functions
  .region(REGION)
  .https.onRequest(async (req, res): Promise<void> => {
    try {
      if (req.method !== "POST") {
        res.status(405).json({
          ok: false,
          error: "method-not-allowed",
        });
        return;
      }

      const uid = await getUidFromRequest(req);

      const {
        organizationId,
        accessToken,
        userId,
        query,
      } = req.body || {};

      if (!organizationId || !accessToken || !userId) {
        res.status(400).json({
          ok: false,
          error: "missing-required-fields",
        });
        return;
      }

      await assertAdmin(organizationId, uid);

      const encryptedAccessToken = encryptText(accessToken);

      await db
        .collection("organizations")
        .doc(organizationId)
        .collection("private")
        .doc("vimeo")
        .set({
          encryptedAccessToken,
          userId,
          query: query || "",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedBy: uid,
        }, { merge: true });

      res.status(200).json({
        ok: true,
      });
      return;
    } catch (error: any) {
      console.error("saveVimeoConfigHttp error:", error);

      if (error.message === "permission-denied") {
        res.status(403).json({
          ok: false,
          error: "permission-denied",
        });
        return;
      }

      res.status(500).json({
        ok: false,
        error: error.message || "internal-error",
      });
      return;
    }
  });

// MARK: - Vimeo設定取得テスト

export const getVimeoConfigHttp = functions
  .region(REGION)
  .https.onRequest(async (req, res): Promise<void> => {
    try {
      if (req.method !== "POST") {
        res.status(405).json({
          ok: false,
          error: "method-not-allowed",
        });
        return;
      }

      const uid = await getUidFromRequest(req);

      const {
        organizationId,
      } = req.body || {};

      if (!organizationId) {
        res.status(400).json({
          ok: false,
          error: "missing-organization-id",
        });
        return;
      }

      await assertAdmin(organizationId, uid);

      const doc = await db
        .collection("organizations")
        .doc(organizationId)
        .collection("private")
        .doc("vimeo")
        .get();

      if (!doc.exists) {
        res.status(404).json({
          ok: false,
          error: "vimeo-config-not-found",
        });
        return;
      }

      const data = doc.data() || {};

      res.status(200).json({
        ok: true,
        userId: data.userId || "",
        query: data.query || "",
        hasAccessToken: !!data.encryptedAccessToken,
      });
      return;
    } catch (error: any) {
      console.error("getVimeoConfigHttp error:", error);

      res.status(500).json({
        ok: false,
        error: error.message || "internal-error",
      });
      return;
    }
  });

// MARK: - Vimeo動画取得

export const fetchVimeoVideosHttp = functions
  .region(REGION)
  .https.onRequest(async (req, res): Promise<void> => {
    try {
      if (req.method !== "POST") {
        res.status(405).json({
          ok: false,
          error: "method-not-allowed",
        });
        return;
      }

      const uid = await getUidFromRequest(req);

      const {
        organizationId,
      } = req.body || {};

      if (!organizationId) {
        res.status(400).json({
          ok: false,
          error: "missing-organization-id",
        });
        return;
      }

      await assertAdmin(organizationId, uid);

      const configDoc = await db
        .collection("organizations")
        .doc(organizationId)
        .collection("private")
        .doc("vimeo")
        .get();

      if (!configDoc.exists) {
        res.status(404).json({
          ok: false,
          error: "vimeo-config-not-found",
        });
        return;
      }

      const config = configDoc.data() || {};
      const accessToken = decryptText(config.encryptedAccessToken);
      const userId = config.userId;
      const query = config.query || "";

      let url = `https://api.vimeo.com/users/${userId}/videos?per_page=50`;

      if (query) {
        url += `&query=${encodeURIComponent(query)}`;
      }

      const response = await axios.get(url, {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });

      const videos = (response.data?.data || []).map((video: any) => {
        return {
          id: video.uri?.split("/").pop() || "",
          title: video.name || "",
          description: video.description || "",
          link: video.link || "",
          duration: video.duration || 0,
          thumbnailUrl: video.pictures?.sizes?.slice(-1)?.[0]?.link || "",
          createdTime: video.created_time || "",
        };
      });

      res.status(200).json({
        ok: true,
        videos,
      });
      return;
    } catch (error: any) {
      console.error("fetchVimeoVideosHttp error:", error?.response?.data || error);

      res.status(500).json({
        ok: false,
        error: error.message || "internal-error",
      });
      return;
    }
  });

// MARK: - メッセージ作成時プッシュ通知

export const onMessageCreated = functions
  .region(REGION)
  .firestore
  .document("organizations/{organizationId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const organizationId = context.params.organizationId;
    const messageId = context.params.messageId;
    const message = snap.data();

    const title = message.title || "新しいお知らせ";
    const body = message.body || "";

    const targetMemberUids: string[] = Array.isArray(message.targetMemberUids)
      ? message.targetMemberUids
      : [];

    const categoryTargets: string[] = Array.isArray(message.categoryTargets)
      ? message.categoryTargets
      : [];

    let membersQuery: FirebaseFirestore.Query = db
      .collection("organizations")
      .doc(organizationId)
      .collection("members")
      .where("status", "==", "approved");

    const membersSnap = await membersQuery.get();

    const tokens: string[] = [];

    membersSnap.docs.forEach((doc) => {
      const member = doc.data();
      const uid = doc.id;

      if (targetMemberUids.length > 0 && !targetMemberUids.includes(uid)) {
        return;
      }

      if (categoryTargets.length > 0) {
        const memberCategories: string[] = Array.isArray(member.categoryIds)
          ? member.categoryIds
          : [];

        const matched = memberCategories.some((categoryId) =>
          categoryTargets.includes(categoryId)
        );

        if (!matched) {
          return;
        }
      }

      if (member.fcmToken) {
        tokens.push(member.fcmToken);
      }
    });

    if (tokens.length === 0) {
      console.log("No FCM tokens", {
        organizationId,
        messageId,
      });
      return;
    }

    const result = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title,
        body,
      },
      data: {
        organizationId,
        messageId,
        type: "message",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    console.log("onMessageCreated result", {
      organizationId,
      messageId,
      targetCount: tokens.length,
      successCount: result.successCount,
      failureCount: result.failureCount,
    });
  });

// MARK: - 未読者への手動/時間指定リマインド

export const sendUnreadReminderHttp = functions
  .region(REGION)
  .https.onRequest(async (req, res): Promise<void> => {
    try {
      if (req.method !== "POST") {
        res.status(405).json({
          ok: false,
          error: "method-not-allowed",
        });
        return;
      }

      const uid = await getUidFromRequest(req);

      const {
        organizationId,
        messageId,
      } = req.body || {};

      if (!organizationId || !messageId) {
        res.status(400).json({
          ok: false,
          error: "missing-required-fields",
        });
        return;
      }

      await assertAdmin(organizationId, uid);

      const messageDoc = await db
        .collection("organizations")
        .doc(organizationId)
        .collection("messages")
        .doc(messageId)
        .get();

      if (!messageDoc.exists) {
        res.status(404).json({
          ok: false,
          error: "message-not-found",
        });
        return;
      }

      const message = messageDoc.data() || {};
      const isReadBy: string[] = Array.isArray(message.isReadBy)
        ? message.isReadBy
        : [];

      const targetMemberUids: string[] = Array.isArray(message.targetMemberUids)
        ? message.targetMemberUids
        : [];

      const categoryTargets: string[] = Array.isArray(message.categoryTargets)
        ? message.categoryTargets
        : [];

      const membersSnap = await db
        .collection("organizations")
        .doc(organizationId)
        .collection("members")
        .where("status", "==", "approved")
        .get();

      const tokens: string[] = [];
      const unreadUids: string[] = [];

      membersSnap.docs.forEach((doc) => {
        const member = doc.data();
        const memberUid = doc.id;

        if (isReadBy.includes(memberUid)) {
          return;
        }

        if (targetMemberUids.length > 0 && !targetMemberUids.includes(memberUid)) {
          return;
        }

        if (categoryTargets.length > 0) {
          const memberCategories: string[] = Array.isArray(member.categoryIds)
            ? member.categoryIds
            : [];

          const matched = memberCategories.some((categoryId) =>
            categoryTargets.includes(categoryId)
          );

          if (!matched) {
            return;
          }
        }

        if (member.fcmToken) {
          tokens.push(member.fcmToken);
          unreadUids.push(memberUid);
        }
      });

      if (tokens.length === 0) {
        res.status(200).json({
          ok: true,
          sent: 0,
          unreadCount: unreadUids.length,
        });
        return;
      }

      const result = await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "未読のお知らせがあります",
          body: message.title || "お知らせをご確認ください",
        },
        data: {
          organizationId,
          messageId,
          type: "unreadReminder",
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
              badge: 1,
            },
          },
        },
      });

      await messageDoc.ref.set({
        lastReminderSentAt: admin.firestore.FieldValue.serverTimestamp(),
        lastReminderSentBy: uid,
      }, { merge: true });

      res.status(200).json({
        ok: true,
        sent: result.successCount,
        failed: result.failureCount,
        unreadCount: unreadUids.length,
      });
      return;
    } catch (error: any) {
      console.error("sendUnreadReminderHttp error:", error);

      res.status(500).json({
        ok: false,
        error: error.message || "internal-error",
      });
      return;
    }
  });