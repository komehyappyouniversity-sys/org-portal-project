//
//  AdminAuthStore.swift
//  ictnagaoka-admin
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications
import UIKit

@MainActor
final class AdminAuthStore: NSObject, ObservableObject {

    @Published var isSignedIn: Bool = false
    @Published var isAdminApproved: Bool = false
    @Published var isLoading: Bool = false

    @Published var currentUid: String?
    @Published var organizationId: String = ""
    @Published var organizationCode: String = ""
    @Published var organizationName: String = ""

    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var adminListener: ListenerRegistration?

    override init() {
        super.init()
        startAuthListener()
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }

        adminListener?.remove()
    }

    // MARK: - Auth Listener

    private func startAuthListener() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }

            self.adminListener?.remove()
            self.adminListener = nil

            self.currentUid = user?.uid
            self.isSignedIn = (user != nil)
            self.isAdminApproved = false
            self.organizationId = ""
            self.organizationCode = ""
            self.organizationName = ""
            self.errorMessage = nil

            guard let uid = user?.uid else {
                print("ℹ️ 管理者ログアウト状態")
                return
            }

            print("🔐 current uid:", uid)

            Task { @MainActor in
                await self.resolveAdminOrganization(uid: uid)
                self.setupNotificationsAndFCM()
                self.refreshFCMTokenIfNeeded()
            }
        }
    }

    // MARK: - Resolve Admin Organization

    private func resolveAdminOrganization(uid: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let organizationsSnapshot = try await db
                .collection("organizations")
                .getDocuments()

            for organizationDocument in organizationsSnapshot.documents {
                let orgId = organizationDocument.documentID
                let orgData = organizationDocument.data()

                let adminSnapshot = try await db
                    .collection("organizations")
                    .document(orgId)
                    .collection("admins")
                    .document(uid)
                    .getDocument()

                guard adminSnapshot.exists else {
                    continue
                }

                let adminData = adminSnapshot.data() ?? [:]

                let approved =
                    (adminData["isApproved"] as? Bool) == true ||
                    (adminData["approved"] as? Bool) == true ||
                    (adminData["isActive"] as? Bool) == true ||
                    (adminData["status"] as? String) == "approved"

                guard approved else {
                    continue
                }

                self.organizationId = orgId
                self.organizationCode =
                    orgData["organizationCode"] as? String
                    ?? orgId

                self.organizationName =
                    orgData["displayName"] as? String
                    ?? orgData["name"] as? String
                    ?? orgId

                self.isAdminApproved = true
                self.isLoading = false
                self.errorMessage = nil

                print("✅ 管理者所属組織を確認")
                print("✅ organizationId:", orgId)
                print("✅ organizationName:", self.organizationName)

                startAdminListener(
                    uid: uid,
                    organizationId: orgId
                )

                return
            }

            self.isAdminApproved = false
            self.isLoading = false
            self.errorMessage = "この管理者が所属する組織が見つかりません。"

            print("❌ 管理者所属組織なし uid:", uid)

        } catch {
            self.isAdminApproved = false
            self.isLoading = false
            self.errorMessage = "管理者所属組織の確認に失敗しました: \(error.localizedDescription)"

            print("❌ 管理者所属組織確認エラー:", error.localizedDescription)
        }
    }

    private func startAdminListener(
        uid: String,
        organizationId: String
    ) {
        adminListener?.remove()

        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            self.errorMessage = "organizationId が空です。"
            self.isAdminApproved = false
            return
        }

        adminListener = db.collection("organizations")
            .document(orgId)
            .collection("admins")
            .document(uid)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    self.errorMessage = "管理者情報の取得に失敗しました: \(error.localizedDescription)"
                    self.isAdminApproved = false
                    print("❌ admin check error:", error.localizedDescription)
                    return
                }

                let exists = snapshot?.exists ?? false
                let data = snapshot?.data() ?? [:]

                guard exists else {
                    self.isAdminApproved = false
                    self.errorMessage = "この組織の管理者として登録されていません。"
                    return
                }

                let approved =
                    (data["isApproved"] as? Bool) == true ||
                    (data["approved"] as? Bool) == true ||
                    (data["isActive"] as? Bool) == true ||
                    (data["status"] as? String) == "approved"

                self.isAdminApproved = approved
                self.errorMessage = approved ? nil : "この組織の管理者権限が有効ではありません。"

                print("🔐 isSignedIn:", self.isSignedIn)
                print("🔐 isAdminApproved:", self.isAdminApproved)
                print("🔐 organizationId:", self.organizationId)
            }
    }

    func restartAdminListenerForSelectedOrganization() {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.isAdminApproved = false
            return
        }

        Task {
            await resolveAdminOrganization(uid: uid)
            refreshFCMTokenIfNeeded()
        }
    }

    // MARK: - Sign In / Out

    func signIn(email: String, password: String) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "メールアドレスとパスワードを入力してください。"
            return
        }

        errorMessage = nil
        isLoading = true

        do {
            let result = try await Auth.auth().signIn(
                withEmail: trimmedEmail,
                password: password
            )

            currentUid = result.user.uid
            isSignedIn = true

            await resolveAdminOrganization(uid: result.user.uid)

            setupNotificationsAndFCM()
            refreshFCMTokenIfNeeded()

        } catch {
            errorMessage = "ログインに失敗しました: \(error.localizedDescription)"
            isSignedIn = false
            isAdminApproved = false
            isLoading = false
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()

            isSignedIn = false
            isAdminApproved = false
            isLoading = false
            currentUid = nil
            organizationId = ""
            organizationCode = ""
            organizationName = ""
            errorMessage = nil

            adminListener?.remove()
            adminListener = nil

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Notifications / FCM

    func setupNotificationsAndFCM() {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        let options: UNAuthorizationOptions = [.alert, .badge, .sound]

        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            if let error {
                print("管理アプリ 通知許可エラー:", error.localizedDescription)
                return
            }

            print("管理アプリ 通知許可:", granted)

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func saveAdminFCMToken(token: String) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("管理者UIDがないためFCMトークン保存をスキップ")
            return
        }

        let orgId = organizationId.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !orgId.isEmpty else {
            print("organizationId がないため管理者FCM保存をスキップ")
            return
        }

        do {
            try await db.collection("organizations")
                .document(orgId)
                .collection("admins")
                .document(uid)
                .setData([
                    "fcmToken": token,
                    "updatedAt": FieldValue.serverTimestamp()
                ], merge: true)

            print("管理者FCMトークン保存成功:", token)

        } catch {
            print("管理者FCMトークン保存失敗:", error.localizedDescription)
        }
    }

    func refreshFCMTokenIfNeeded() {
        Messaging.messaging().token { [weak self] token, error in
            if let error {
                print("管理者FCMトークン取得失敗:", error.localizedDescription)
                return
            }

            guard let token else { return }

            Task {
                await self?.saveAdminFCMToken(token: token)
            }
        }
    }
}

// MARK: - MessagingDelegate

extension AdminAuthStore: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("管理者FCMトークン:", fcmToken ?? "nil")

        guard let token = fcmToken else { return }

        Task {
            await saveAdminFCMToken(token: token)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AdminAuthStore: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        print("管理アプリ 通知タップ:", response.notification.request.content.userInfo)
    }
}
