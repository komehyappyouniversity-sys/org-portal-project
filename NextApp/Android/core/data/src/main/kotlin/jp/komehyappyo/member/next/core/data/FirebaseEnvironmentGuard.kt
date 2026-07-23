package jp.komehyappyo.member.next.core.data

object FirebaseEnvironmentGuard {
    const val PRODUCTION_PROJECT_ID = "ictnagaoka-member"

    fun requireSafeDebugProject(isDebug: Boolean, configuredProjectId: String?) {
        if (isDebug && configuredProjectId == PRODUCTION_PROJECT_ID) {
            error("安全のため起動を停止しました。Debugビルドは本番Firebaseへ接続できません。")
        }
    }
}

/**
 * Firestore/Auth/Storageの実装と旧データ変換は、このDataモジュールの配下だけに置く。
 * 実SDKは開発用Firebase設定を用意する後続タスクで追加する。
 */
interface LegacyAdapter<Legacy, Domain> {
    fun convert(value: Legacy): Domain
}
