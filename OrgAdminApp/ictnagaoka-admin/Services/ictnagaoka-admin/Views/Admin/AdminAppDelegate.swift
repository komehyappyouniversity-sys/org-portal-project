import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

final class AdminAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        requestNotificationPermission(application: application)

        return true
    }

    private func requestNotificationPermission(application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            if let error {
                print("管理アプリ 通知許可エラー:", error.localizedDescription)
            }

            print("管理アプリ 通知許可:", granted)

            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken

        print("✅ 管理アプリ APNs token 登録完了")

        Messaging.messaging().token { token, error in
            if let error {
                print("❌ APNs後 管理者FCMトークン取得失敗:", error.localizedDescription)
                return
            }

            guard let token, !token.isEmpty else {
                print("❌ APNs後 管理者FCMトークン nil")
                return
            }

            print("✅ APNs後 管理者FCMトークン取得:", token)

        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ 管理アプリ APNs token 登録失敗:", error.localizedDescription)
    }

    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        print("管理アプリ FCMトークン:", fcmToken ?? "nil")
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
        print("管理アプリ 通知タップ:", response.notification.request.content.userInfo)
        completionHandler()
    }
}
