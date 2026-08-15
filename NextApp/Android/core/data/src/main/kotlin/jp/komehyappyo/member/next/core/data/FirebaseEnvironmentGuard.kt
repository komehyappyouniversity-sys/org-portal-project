package jp.komehyappyo.member.next.core.data

object FirebaseEnvironmentGuard {
    const val PRODUCTION_PROJECT_ID = "ictnagaoka-member"
    const val DEVELOPMENT_PROJECT_ID = "kome-org-portal-next-dev"
    const val EMULATOR_PROJECT_ID = "demo-org-portal-next"

    fun requireSafeDebugProject(isDebug: Boolean, configuredProjectId: String?) {
        if (isDebug && configuredProjectId !in setOf(DEVELOPMENT_PROJECT_ID, EMULATOR_PROJECT_ID)) {
            error(
                "安全のため起動を停止しました。Debugビルドは開発用FirebaseまたはEmulatorのみ利用できます。",
            )
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
