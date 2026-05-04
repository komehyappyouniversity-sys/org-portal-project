import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

export const sendMessageNotification = onDocumentCreated(
  {
    document: "organizations/{organizationId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.info("No snapshot");
      return;
    }

    const organizationId = event.params.organizationId;
    const messageId = event.params.messageId;
    const data = snapshot.data();

    const title = String(data.title ?? "お知らせ");
    const body = String(data.body ?? "");
    const isBroadcast = data.isBroadcast === true;
    const categoryTargets = Array.isArray(data.categoryTargets)
      ? data.categoryTargets.filter((v) => typeof v === "string")
      : [];
    const targetMemberUids = Array.isArray(data.targetMemberUids)
      ? data.targetMemberUids.filter((v) => typeof v === "string")
      : [];
    const toUids = Array.isArray(data.toUids)
      ? data.toUids.filter((v) => typeof v === "string")
      : [];

    logger.info("通知作成開始", {
      organizationId,
      messageId,
      title,
      isBroadcast,
      categoryTargets,
      targetMemberUids,
      toUids,
    });

    const membersRef = db
      .collection("organizations")
      .doc(organizationId)
      .collection("members");

    let memberSnapshots: FirebaseFirestore.QueryDocumentSnapshot[] = [];

    if (isBroadcast) {
      const membersSnapshot = await membersRef.get();
      memberSnapshots = membersSnapshot.docs;
    } else if (categoryTargets.length > 0) {
      const membersSnapshot = await membersRef.get();

      memberSnapshots = membersSnapshot.docs.filter((doc) => {
        const member = doc.data();

        const categories = Array.isArray(member.categories)
          ? member.categories.filter((v) => typeof v === "string")
          : [];

        const legacyCategory =
          typeof member.category === "string" ? member.category : "";

        const allCategories = [...categories];

        if (legacyCategory) {
          allCategories.push(legacyCategory);
        }

        return allCategories.some((category) =>
          categoryTargets.includes(category)
        );
      });
    } else if (targetMemberUids.length > 0 || toUids.length > 0) {
      const uidSet = new Set<string>([...targetMemberUids, ...toUids]);

      const docs = await Promise.all(
        Array.from(uidSet).map((uid) => membersRef.doc(uid).get())
      );

      memberSnapshots = docs.filter(
        (doc): doc is FirebaseFirestore.QueryDocumentSnapshot =>
          doc.exists
      );
    } else {
      logger.info("通知対象なし");
      return;
    }

    const tokens = memberSnapshots
      .map((doc) => doc.data().fcmToken)
      .filter((token): token is string => typeof token === "string" && token.length > 0);

    const uniqueTokens = Array.from(new Set(tokens));

    logger.info("通知対象トークン数", {
      count: uniqueTokens.length,
    });

    if (uniqueTokens.length === 0) {
      logger.info("FCMトークンなし");
      return;
    }

    const message: admin.messaging.MulticastMessage = {
      tokens: uniqueTokens,
      notification: {
        title,
        body,
      },
      data: {
        type: "message",
        messageId,
        organizationId,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    logger.info("通知送信完了", {
      successCount: response.successCount,
      failureCount: response.failureCount,
    });

    response.responses.forEach((result, index) => {
      if (!result.success) {
        logger.error("通知送信失敗", {
          token: uniqueTokens[index],
          error: result.error?.message,
        });
      }
    });
  }
);
