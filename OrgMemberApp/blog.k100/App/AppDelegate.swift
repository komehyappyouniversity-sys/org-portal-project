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

final class AppDelegate: NSObject,
                         UIApplicationDelegate,
                         UNUserNotificationCenterDelegate,
                         MessagingDelegate {

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

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            Messaging.messaging().token { token, error in

                if let error {
                    print("❌ FCM token取得失敗:", error.localizedDescription)
                    return
                }

                guard let token else {
                    print("❌ FCM token nil")
                    return
                }

                print("✅ 強制取得FCM token:", token)

                self.saveFCMTokenToFirestore(token)
            }
        }

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        Messaging.messaging().token { token, error in
            if let error {
                print("❌ FCM token再取得失敗:", error.localizedDescription)
                return
            }

            guard let token, !token.isEmpty else {
                print("❌ FCM token再取得 nil")
                return
            }

            print("✅ FCM token再取得:", token)
            self.saveFCMTokenToFirestore(token)
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken

        print("✅ APNs token 登録完了")

        Messaging.messaging().token { token, error in
            if let error {
                print("❌ APNs後 FCM token取得失敗:", error.localizedDescription)
                return
            }

            guard let token, !token.isEmpty else {
                print("❌ APNs後 FCM token nil")
                return
            }

            print("✅ APNs後 FCM token取得:", token)
            self.saveFCMTokenToFirestore(token)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs token 登録失敗:", error.localizedDescription)
    }

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken,
              !fcmToken.isEmpty else {

            print("❌ FCM token nil")
            return
        }

        print("✅ didReceiveRegistrationToken:", fcmToken)

        saveFCMTokenToFirestore(fcmToken)
    }

    private func saveFCMTokenToFirestore(_ token: String) {

        guard let uid = Auth.auth().currentUser?.uid else {

            print("⚠️ UID未取得")

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.saveFCMTokenToFirestore(token)
            }

            return
        }

        do {

            let service = MemberOrganizationService()

            guard let selection = try service.loadLocalOrganizationSelection()
            else {
                print("❌ organization selection なし")
                return
            }

            let organizationId = selection.organizationId
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if organizationId.isEmpty {
                print("❌ organizationId 空")
                return
            }

            Firestore.firestore()
                .collection("organizations")
                .document(organizationId)
                .collection("members")
                .document(uid)
                .setData([
                    "uid": uid,
                    "fcmToken": token,
                    "fcmTokenUpdatedAt": FieldValue.serverTimestamp()
                ], merge: true) { error in

                    if let error {
                        print("❌ FCM token 保存失敗:",
                              error.localizedDescription)
                    } else {
                        print("✅ FCM token 保存成功 organizationId:",
                              organizationId,
                              "uid:",
                              uid)
                    }
                }

        } catch {

            print("❌ organization 読み込み失敗:",
                  error.localizedDescription)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void
    ) {

        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler:
        @escaping () -> Void
    ) {

        completionHandler()
    }
}
