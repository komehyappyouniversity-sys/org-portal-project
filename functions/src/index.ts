import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import axios from "axios";
import * as crypto from "crypto";

admin.initializeApp();

const db = admin.firestore();
const REGION = "asia-northeast1";

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

async function isSuperAdmin(uid: string): Promise<boolean> {
  const doc = await db.collection("superAdmins").doc(uid).get();
  return doc.exists && doc.data()?.isActive === true;
}

async function assertAdminOrSuperAdmin(
  organizationId: string,
  uid: string
): Promise<void> {
  const superAdmin = await isSuperAdmin(uid);

  if (superAdmin) {
    return;
  }

  await assertAdmin(organizationId, uid);
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

async function getCallableUid(
  data: any,
  context: functions.https.CallableContext
): Promise<string> {
  console.log("getCallableUid called", {
    hasContextAuth: !!context.auth?.uid,
    contextUid: context.auth?.uid || "",
    hasIdToken: !!data?.idToken,
    idTokenPrefix: String(data?.idToken || "").slice(0, 20),
  });

  if (context.auth?.uid) {
    return context.auth.uid;
  }

  const idToken = String(data?.idToken || "").trim();

  if (!idToken) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication required. No idToken."
    );
  }

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    console.log("idToken verified", {
      uid: decoded.uid,
      aud: decoded.aud,
      iss: decoded.iss,
    });
    return decoded.uid;
  } catch (error) {
    console.error("verifyIdToken failed", error);
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Invalid idToken."
    );
  }
}

// MARK: - Vimeo設定保存（callable版）

export const saveVimeoConfig = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const uid = await getCallableUid(data, context);

    const organizationId = String(data.organizationId || "").trim();
    const accessToken = String(data.accessToken || "").trim();
    const userId = String(data.userId || "").trim();
    const query = String(data.query || "").trim();

    if (!organizationId || !accessToken || !userId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "organizationId, accessToken, userId が必要です"
      );
    }

    await assertAdminOrSuperAdmin(organizationId, uid);

    await db
      .collection("organizations")
      .doc(organizationId)
      .collection("private")
      .doc("vimeo")
      .set({
        encryptedAccessToken: encryptText(accessToken),
        userId,
        query,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: uid,
      }, { merge: true });

    return { ok: true };
  });

// MARK: - Vimeo設定取得（callable版）

export const getVimeoConfig = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const uid = await getCallableUid(data, context);

    const organizationId = String(data.organizationId || "").trim();

    if (!organizationId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "organizationId が必要です"
      );
    }

    await assertAdminOrSuperAdmin(organizationId, uid);

    const doc = await db
      .collection("organizations")
      .doc(organizationId)
      .collection("private")
      .doc("vimeo")
      .get();

    if (!doc.exists) {
      return {
        accessToken: "",
        userId: "",
        query: "",
      };
    }

    const saved = doc.data() || {};
    const encryptedAccessToken = saved.encryptedAccessToken || "";

    return {
      accessToken: encryptedAccessToken ? decryptText(encryptedAccessToken) : "",
      userId: saved.userId || "",
      query: saved.query || "",
    };
  });

// MARK: - Vimeo動画取得（callable版）

export const fetchVimeoVideos = functions
  .region(REGION)
  .https.onCall(async (data, context) => {
    const uid = await getCallableUid(data, context);

    const organizationId = String(data.organizationId || "").trim();

    if (!organizationId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "organizationId が必要です"
      );
    }

    await assertAdminOrSuperAdmin(organizationId, uid);

    const configDoc = await db
      .collection("organizations")
      .doc(organizationId)
      .collection("private")
      .doc("vimeo")
      .get();

    if (!configDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Vimeo設定がありません"
      );
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

    return {
      ok: true,
      videos,
    };
  });

// MARK: - Vimeo設定保存（HTTP版）

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

      await assertAdminOrSuperAdmin(organizationId, uid);

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

      if (
        error.message === "permission-denied" ||
        error.message === "missing-auth-token"
      ) {
        res.status(403).json({
          ok: false,
          error: error.message,
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

// MARK: - Vimeo設定取得（HTTP版）

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

      await assertAdminOrSuperAdmin(organizationId, uid);

      const doc = await db
        .collection("organizations")
        .doc(organizationId)
        .collection("private")
        .doc("vimeo")
        .get();

      if (!doc.exists) {
        res.status(200).json({
          ok: true,
          accessToken: "",
          userId: "",
          query: "",
          hasAccessToken: false,
        });
        return;
      }

      const data = doc.data() || {};
      const encryptedAccessToken = data.encryptedAccessToken || "";

      res.status(200).json({
        ok: true,
        accessToken: encryptedAccessToken ? decryptText(encryptedAccessToken) : "",
        userId: data.userId || "",
        query: data.query || "",
        hasAccessToken: !!encryptedAccessToken,
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

// MARK: - Vimeo動画取得（HTTP版）

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

      await assertAdminOrSuperAdmin(organizationId, uid);

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
    try {
      const organizationId = context.params.organizationId;
      const messageId = context.params.messageId;
      const message = snap.data();

      const title = String(message.title || "新しいお知らせ");
      const body = String(message.body || "");

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
        .where("status", "in", ["approved", "active"])
        .get();

      const tokens: string[] = [];
      const tokenOwners: string[] = [];

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
          tokens.push(String(member.fcmToken));
          tokenOwners.push(uid);
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
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              alert: {
                title,
                body,
              },
              sound: "default",
              badge: 1,
            },
          },
        },
      });

      const deleteInvalidTokenPromises: Promise<FirebaseFirestore.WriteResult>[] = [];

      result.responses.forEach((response, index) => {
        if (response.success) {
          return;
        }

        const uid = tokenOwners[index];
        const token = tokens[index];
        const errorCode = response.error?.code || "";
        const errorMessage = response.error?.message || "";

        console.error("FCM send failure", {
          organizationId,
          messageId,
          uid,
          tokenPrefix: token?.slice(0, 16),
          code: errorCode,
          message: errorMessage,
        });

        if (
          errorCode === "messaging/registration-token-not-registered" ||
          errorCode === "messaging/invalid-registration-token"
        ) {
          const memberRef = db
            .collection("organizations")
            .doc(organizationId)
            .collection("members")
            .doc(uid);

          deleteInvalidTokenPromises.push(
            memberRef.update({
              fcmToken: admin.firestore.FieldValue.delete(),
              fcmTokenUpdatedAt: admin.firestore.FieldValue.delete(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            })
          );

          console.log("Invalid fcmToken delete scheduled", {
            organizationId,
            messageId,
            uid,
            code: errorCode,
          });
        }
      });

      if (deleteInvalidTokenPromises.length > 0) {
        await Promise.all(deleteInvalidTokenPromises);

        console.log("Invalid fcmToken deleted", {
          organizationId,
          messageId,
          deletedCount: deleteInvalidTokenPromises.length,
        });
      }

      console.log("onMessageCreated result", {
        organizationId,
        messageId,
        targetCount: tokens.length,
        successCount: result.successCount,
        failureCount: result.failureCount,
      });
    } catch (error: any) {
      console.error("onMessageCreated error", {
        message: error?.message,
        code: error?.code,
        stack: error?.stack,
      });
    }
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

      await assertAdminOrSuperAdmin(organizationId, uid);

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
      const title = "未読のお知らせがあります";
      const body = String(message.title || "お知らせをご確認ください");

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
        .where("status", "in", ["approved", "active"])
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
          tokens.push(String(member.fcmToken));
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
          title,
          body,
        },
        data: {
          organizationId,
          messageId,
          type: "unreadReminder",
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              alert: {
                title,
                body,
              },
              sound: "default",
              badge: 1,
            },
          },
        },
      });

      result.responses.forEach((response, index) => {
        if (!response.success) {
          console.error("Unread reminder FCM failure", {
            organizationId,
            messageId,
            uid: unreadUids[index],
            tokenPrefix: tokens[index]?.slice(0, 16),
            code: response.error?.code,
            message: response.error?.message,
          });
        }
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

// MARK: - 組織作成時 初期データ自動生成

export const onOrganizationCreated = functions
  .region(REGION)
  .firestore
  .document("organizations/{organizationId}")
  .onCreate(async (snap, context) => {
    const organizationId = context.params.organizationId;
    const organization = snap.data() || {};
    const createdByUid = String(organization.createdByUid || "").trim();
    const createdByEmail = String(organization.createdByEmail || "").trim();

    console.log("onOrganizationCreated start", {
      organizationId,
    });

    const organizationRef = db
      .collection("organizations")
      .doc(organizationId);

    await organizationRef
      .collection("settings")
      .doc("adminFeatures")
      .set({
        announcementEnabled: true,
        messageEnabled: true,
        bookingEnabled: false,
        videoEnabled: false,
        paidVideoEnabled: false,
        scheduleEnabled: false,
        memberPostEnabled: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

    await organizationRef
      .collection("settings")
      .doc("memberFeatures")
      .set({
        announcementEnabled: true,
        messageEnabled: true,
        bookingEnabled: false,
        videoEnabled: false,
        paidVideoEnabled: false,
        scheduleEnabled: false,
        memberPostEnabled: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

    await organizationRef
      .collection("settings")
      .doc("default")
      .set({
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

    await organizationRef
      .collection("categories")
      .doc("default")
      .set({
        name: "一般",
        sortOrder: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

    if (createdByUid) {
      await organizationRef
        .collection("admins")
        .doc(createdByUid)
        .set({
          uid: createdByUid,
          email: createdByEmail,
          name: createdByEmail,
          role: "owner",
          isActive: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }

    console.log("onOrganizationCreated completed", {
      organizationId,
    });
  });
 // MARK: - 管理者FCMトークン取得

async function getActiveAdminTokens(organizationId: string): Promise<string[]> {
  const adminsSnap = await db
    .collection("organizations")
    .doc(organizationId)
    .collection("admins")
    .where("isActive", "==", true)
    .get();

  const tokens: string[] = [];

  adminsSnap.docs.forEach((doc) => {
    const adminData = doc.data();
    const token = String(adminData.fcmToken || "").trim();

    if (token) {
      tokens.push(token);
    }
  });

  return tokens;
}

// MARK: - 会員登録申請時 管理者通知

export const onMemberRegistrationCreated = functions
  .region(REGION)
  .firestore
  .document("organizations/{organizationId}/memberRegistrations/{registrationId}")
  .onCreate(async (snap, context) => {
    const organizationId = context.params.organizationId;
    const registration = snap.data() || {};

    const name = String(registration.name || "新しい会員");
    const tokens = await getActiveAdminTokens(organizationId);

    if (tokens.length === 0) {
      console.log("管理者FCMトークンなし", {
        organizationId,
        type: "memberRegistration",
      });
      return;
    }

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "新しい会員登録申請があります",
        body: `${name} さんから会員登録申請が届きました。`,
      },
      data: {
        organizationId,
        type: "memberRegistration",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: {
              title: "新しい会員登録申請があります",
              body: `${name} さんから会員登録申請が届きました。`,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    console.log("会員登録申請通知送信完了", {
      organizationId,
      targetCount: tokens.length,
    });
  });

// MARK: - 会員投稿時 管理者通知

export const onMemberPostCreated = functions
  .region(REGION)
  .firestore
  .document("organizations/{organizationId}/memberPosts/{postId}")
  .onCreate(async (snap, context) => {
    const organizationId = context.params.organizationId;
    const postId = context.params.postId;
    const post = snap.data() || {};

    const memberName = String(post.memberName || "会員");
    const postTitle = String(post.title || "新しい投稿");
    const tokens = await getActiveAdminTokens(organizationId);

    if (tokens.length === 0) {
      console.log("管理者FCMトークンなし", {
        organizationId,
        postId,
        type: "memberPost",
      });
      return;
    }

    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "会員から投稿が届きました",
        body: `${memberName} さん：${postTitle}`,
      },
      data: {
        organizationId,
        postId,
        type: "memberPost",
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: {
              title: "会員から投稿が届きました",
              body: `${memberName} さん：${postTitle}`,
            },
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    console.log("会員投稿通知送信完了", {
      organizationId,
      postId,
      targetCount: tokens.length,
    });
  });
   