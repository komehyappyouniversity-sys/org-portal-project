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
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private let organizationService = OrganizationService()

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

            self.currentUid = user?.uid
            self.isSignedIn = (user != nil)
            self.errorMessage = nil

            self.adminListener?.remove()
            self.adminListener = nil
            self.isAdminApproved = false

            guard let uid = user?.uid else { return }

            print("🔐 current uid:", uid)

            Task { @MainActor in
                self.startAdminListenerIfOrganizationSelected(uid: uid)
                self.setupNotificationsAndFCM()
                self.refreshFCMTokenIfNeeded()
            }
        }
    }

    private func startAdminListenerIfOrganizationSelected(uid: String) {
        do {
            guard let selection = try organizationService.loadLocalOrganizationSelection() else {
                print("ℹ️ 保存済み organizationId なし。組織コード入力後に管理者確認します。")
                self.isAdminApproved = false
                self.errorMessage = nil
                return
            }

            let organizationId = selection.organizationId
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !organizationId.isEmpty else {
                self.errorMessage = "保存済み organizationId が空です。"
                self.isAdminApproved = false
                return
            }

            print("🔐 saved organizationId:", organizationId)

            startAdminListener(
                uid: uid,
                organizationId: organizationId
            )

        } catch {
            self.errorMessage = "保存済み組織情報の読み込みに失敗しました: \(error.localizedDescription)"
            self.isAdminApproved = false
            print("❌ load organization selection error:", error.localizedDescription)
        }
    }

    func restartAdminListenerForSelectedOrganization() {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.isAdminApproved = false
            return
        }

        startAdminListenerIfOrganizationSelected(uid: uid)
        refreshFCMTokenIfNeeded()
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

                print("🔐 admin doc exists:", exists)
                print("🔐 admin data:", data)

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
            isLoading = false

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

        let organizationId: String

        do {
            guard let selection = try organizationService.loadLocalOrganizationSelection() else {
                print("保存済み organizationId がないため管理者FCM保存をスキップ")
                return
            }

            organizationId = selection.organizationId
                .trimmingCharacters(in: .whitespacesAndNewlines)

        } catch {
            print("保存済み organizationId 読み込み失敗:", error.localizedDescription)
            return
        }

        guard !organizationId.isEmpty else {
            print("organizationId がないため管理者FCM保存をスキップ")
            return
        }

        do {
            try await db.collection("organizations")
                .document(organizationId)
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
