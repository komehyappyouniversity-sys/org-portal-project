import SwiftUI

struct MemberAreaGateView: View {
    @EnvironmentObject private var memberStore: MemberStore
    @EnvironmentObject private var securityStore: MemberSecurityStore

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            // 🔹 未ログイン
            if memberStore.authUid == nil {
                VStack(spacing: 16) {
                    Text("ログインしてください")
                        .font(.title3.bold())
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 🔹 会員データ未取得
            } else if memberStore.profile == nil {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("会員情報を確認しています...")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 🔹 未承認（ここが重要）
            } else if memberStore.profile?.isApproved == false {
                VStack(spacing: 20) {
                    Image(systemName: "hourglass")
                        .font(.largeTitle)
                        .foregroundColor(.orange)

                    Text("承認待ちです")
                        .font(.title2.bold())

                    Text("管理者の承認後に会員ページを利用できます。")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 🔹 承認済み → Face ID ロック
            } else {
                if securityStore.isUnlocked {
                    MemberPageView()
                } else {
                    BiometricLockView()
                }
            }
        }
        .onAppear {
            handleAuth()
        }
        .onChange(of: scenePhase) { _, newPhase in
            securityStore.handleScenePhaseChange(to: newPhase)
        }
    }

    private func handleAuth() {
        guard memberStore.profile?.isApproved == true else { return }
        securityStore.authenticateIfNeededOnFirstEntry()
    }
}
