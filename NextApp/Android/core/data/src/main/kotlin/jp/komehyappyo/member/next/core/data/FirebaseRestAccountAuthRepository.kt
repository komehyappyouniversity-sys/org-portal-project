package jp.komehyappyo.member.next.core.data

import jp.komehyappyo.member.next.core.model.AccountCredentials
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant

class FirebaseRestAccountAuthRepository(
    private val apiKey: String,
    private val projectId: String,
) : AccountAuthRepository {
    override suspend fun register(credentials: AccountCredentials): Result<AuthenticatedAccount> =
        runCatching {
            val response = request(
                endpoint = "accounts:signUp",
                body = JSONObject()
                    .put("email", credentials.email.trim())
                    .put("password", credentials.password)
                    .put("returnSecureToken", true),
            )
            val idToken = response.getString("idToken")
            val refreshToken = response.getString("refreshToken")
            val userId = response.getString("localId")
            val email = response.getString("email")
            val name = credentials.name.orEmpty().trim()
            val furigana = credentials.furigana.orEmpty().trim()
            updateDisplayName(idToken, name)
            saveMemberProfile(
                idToken = idToken,
                userId = userId,
                email = email,
                name = name,
                furigana = furigana,
            )
            sendEmailVerification(idToken)
            AuthenticatedAccount(
                userId = userId,
                email = email,
                emailVerified = false,
                idToken = idToken,
                refreshToken = refreshToken,
            )
        }

    override suspend fun login(credentials: AccountCredentials): Result<AuthenticatedAccount> =
        runCatching {
            val response = request(
                endpoint = "accounts:signInWithPassword",
                body = JSONObject()
                    .put("email", credentials.email.trim())
                    .put("password", credentials.password)
                    .put("returnSecureToken", true),
            )
            val idToken = response.getString("idToken")
            val refreshToken = response.getString("refreshToken")
            val account = lookup(idToken, refreshToken)
            if (!account.emailVerified) {
                sendEmailVerification(idToken)
                throw FirebaseAuthException(
                    "メールアドレスの確認が完了していません。確認メールを再送しました。",
                )
            }
            account
        }

    override suspend fun refresh(refreshToken: String): Result<AuthenticatedAccount> =
        runCatching {
            val response = refreshRequest(refreshToken)
            lookup(
                idToken = response.getString("id_token"),
                refreshToken = response.getString("refresh_token"),
            )
        }

    override suspend fun sendPasswordReset(email: String): Result<Unit> =
        runCatching {
            request(
                endpoint = "accounts:sendOobCode",
                body = JSONObject()
                    .put("requestType", "PASSWORD_RESET")
                    .put("email", email.trim()),
            )
            Unit
        }

    private suspend fun lookup(
        idToken: String,
        refreshToken: String,
    ): AuthenticatedAccount {
        val response = request(
            endpoint = "accounts:lookup",
            body = JSONObject().put("idToken", idToken),
        )
        val user = response.getJSONArray("users").getJSONObject(0)
        return AuthenticatedAccount(
            userId = user.getString("localId"),
            email = user.getString("email"),
            emailVerified = user.optBoolean("emailVerified", false),
            idToken = idToken,
            refreshToken = refreshToken,
        )
    }

    private suspend fun refreshRequest(refreshToken: String): JSONObject =
        withContext(Dispatchers.IO) {
            val connection = (
                URL("$SECURE_TOKEN_URL?key=$apiKey").openConnection() as HttpURLConnection
                ).apply {
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 15_000
                doOutput = true
                setRequestProperty(
                    "Content-Type",
                    "application/x-www-form-urlencoded",
                )
            }
            val body = "grant_type=refresh_token&refresh_token=" +
                java.net.URLEncoder.encode(refreshToken, Charsets.UTF_8.name())
            try {
                connection.outputStream.use {
                    it.write(body.toByteArray(Charsets.UTF_8))
                }
                val responseText = (
                    if (connection.responseCode in 200..299) {
                        connection.inputStream
                    } else {
                        connection.errorStream
                    }
                    ).bufferedReader().use { it.readText() }
                if (connection.responseCode !in 200..299) {
                    throw FirebaseAuthException(
                        "生体認証ログインの有効期限が切れました。パスワードで再度ログインしてください。",
                    )
                }
                JSONObject(responseText)
            } finally {
                connection.disconnect()
            }
        }

    private suspend fun sendEmailVerification(idToken: String) {
        request(
            endpoint = "accounts:sendOobCode",
            body = JSONObject()
                .put("requestType", "VERIFY_EMAIL")
                .put("idToken", idToken),
        )
    }

    private suspend fun updateDisplayName(idToken: String, name: String) {
        request(
            endpoint = "accounts:update",
            body = JSONObject()
                .put("idToken", idToken)
                .put("displayName", name)
                .put("returnSecureToken", true),
        )
    }

    private suspend fun saveMemberProfile(
        idToken: String,
        userId: String,
        email: String,
        name: String,
        furigana: String,
    ) = withContext(Dispatchers.IO) {
        val now = Instant.now().toString()
        val fields = JSONObject()
            .put("uid", JSONObject().put("stringValue", userId))
            .put("email", JSONObject().put("stringValue", email))
            .put("name", JSONObject().put("stringValue", name))
            .put("furigana", JSONObject().put("stringValue", furigana))
            .put("createdAt", JSONObject().put("timestampValue", now))
            .put("updatedAt", JSONObject().put("timestampValue", now))
        val connection = (
            URL(
                "$FIRESTORE_BASE_URL/projects/$projectId/databases/(default)" +
                    "/documents/memberPrivate/$userId",
            ).openConnection() as HttpURLConnection
            ).apply {
            requestMethod = "PATCH"
            connectTimeout = 15_000
            readTimeout = 15_000
            doOutput = true
            setRequestProperty("Authorization", "Bearer $idToken")
            setRequestProperty("Content-Type", "application/json; charset=UTF-8")
        }
        try {
            connection.outputStream.use {
                it.write(JSONObject().put("fields", fields).toString().toByteArray(Charsets.UTF_8))
            }
            if (connection.responseCode !in 200..299) {
                throw FirebaseProfileException(
                    "アカウントは作成されましたが、会員情報を保存できませんでした。",
                )
            }
        } finally {
            connection.disconnect()
        }
    }

    private suspend fun request(endpoint: String, body: JSONObject): JSONObject =
        withContext(Dispatchers.IO) {
            val connection = (
                URL("$BASE_URL/$endpoint?key=$apiKey").openConnection() as HttpURLConnection
                ).apply {
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 15_000
                doOutput = true
                setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            }
            try {
                connection.outputStream.use {
                    it.write(body.toString().toByteArray(Charsets.UTF_8))
                }
                val responseText = (
                    if (connection.responseCode in 200..299) {
                        connection.inputStream
                    } else {
                        connection.errorStream
                    }
                    ).bufferedReader().use { it.readText() }
                val response = JSONObject(responseText)
                if (connection.responseCode !in 200..299) {
                    val code = response.optJSONObject("error")
                        ?.optString("message")
                        .orEmpty()
                    throw FirebaseAuthException(localizedMessage(code))
                }
                response
            } finally {
                connection.disconnect()
            }
        }

    private fun localizedMessage(code: String): String = when {
        code == "EMAIL_EXISTS" -> "このメールアドレスはすでに登録されています。"
        code == "EMAIL_NOT_FOUND" || code == "INVALID_LOGIN_CREDENTIALS" ->
            "メールアドレスまたはパスワードが正しくありません。"
        code == "INVALID_PASSWORD" -> "メールアドレスまたはパスワードが正しくありません。"
        code == "USER_DISABLED" -> "このアカウントは利用停止中です。"
        code == "TOO_MANY_ATTEMPTS_TRY_LATER" -> "試行回数が多すぎます。時間をおいて再度お試しください。"
        code.startsWith("WEAK_PASSWORD") -> "パスワードは8文字以上で入力してください。"
        else -> "認証処理に失敗しました。通信環境を確認して再度お試しください。"
    }

    private companion object {
        const val BASE_URL = "https://identitytoolkit.googleapis.com/v1"
        const val FIRESTORE_BASE_URL = "https://firestore.googleapis.com/v1"
        const val SECURE_TOKEN_URL = "https://securetoken.googleapis.com/v1/token"
    }
}

class FirebaseAuthException(message: String) : IllegalStateException(message)
class FirebaseProfileException(message: String) : IllegalStateException(message)
