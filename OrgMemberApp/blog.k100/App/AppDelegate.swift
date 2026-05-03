//
//  AppDelegate.swift
//  blog.k100
//

import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    private let organizationId = "nagaoka"

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {

        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if let error {
                print("❌ 通知許可エラー:", error.localizedDescription)
            } else {
                print("✅ 通知許可:", granted)
            }
        }

        application.registerForRemoteNotifications()

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNs token 登録完了")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs token 登録失敗:", error.localizedDescription)
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else {
            print("❌ FCM token が nil または空です")
            return
        }

        print("✅ FCM token:", fcmToken)

        saveFCMTokenToFirestore(fcmToken)
    }

    private func saveFCMTokenToFirestore(_ token: String) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("⚠️ UID未取得のため、FCM token 保存を保留します")

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.saveFCMTokenToFirestore(token)
            }
            return
        }

        let db = Firestore.firestore()

        db.collection("organizations")
            .document(organizationId)
            .collection("members")
            .document(uid)
            .setData([
                "uid": uid,
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
            ], merge: true) { error in
                if let error {
                    print("❌ FCM token 保存失敗:", error.localizedDescription)
                } else {
                    print("✅ FCM token 保存成功 uid:", uid)
                }
            }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
