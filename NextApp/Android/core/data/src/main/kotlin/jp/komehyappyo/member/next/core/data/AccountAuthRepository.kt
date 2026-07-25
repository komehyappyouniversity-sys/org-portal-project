package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.AccountCredentials

data class AuthenticatedAccount(
    val userId: String,
    val email: String,
)

interface AccountAuthRepository {
    suspend fun register(credentials: AccountCredentials): Result<AuthenticatedAccount>
    suspend fun login(credentials: AccountCredentials): Result<AuthenticatedAccount>
    suspend fun sendPasswordReset(email: String): Result<Unit>
}

class DevelopmentFirebaseNotConfiguredException :
    IllegalStateException("開発用Firebase認証が未設定です。本番Firebaseには接続していません。")

/**
 * 開発用Firebase設定を安全に追加するまで使う明示的な未接続実装。
 * 認証成功を装わず、本番Firebaseにも接続しない。
 */
class UnavailableAccountAuthRepository : AccountAuthRepository {
    override suspend fun register(credentials: AccountCredentials) =
        Result.failure<AuthenticatedAccount>(DevelopmentFirebaseNotConfiguredException())

    override suspend fun login(credentials: AccountCredentials) =
        Result.failure<AuthenticatedAccount>(DevelopmentFirebaseNotConfiguredException())

    override suspend fun sendPasswordReset(email: String) =
        Result.failure<Unit>(DevelopmentFirebaseNotConfiguredException())
}
