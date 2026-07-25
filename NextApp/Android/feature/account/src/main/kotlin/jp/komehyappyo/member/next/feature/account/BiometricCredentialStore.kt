package jp.komehyappyo.member.next.feature.account

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Firebaseの更新トークンだけをAndroid Keystore鍵で暗号化して端末内へ保存する。
 * メールアドレスやパスワードは保存しない。
 */
class BiometricCredentialStore(context: Context) {
    private val preferences = context.getSharedPreferences(
        "biometric_login",
        Context.MODE_PRIVATE,
    )

    val hasCredential: Boolean
        get() = preferences.contains(KEY_CIPHERTEXT) && preferences.contains(KEY_IV)

    fun save(refreshToken: String) {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val encrypted = cipher.doFinal(refreshToken.toByteArray(Charsets.UTF_8))
        preferences.edit()
            .putString(KEY_CIPHERTEXT, Base64.encodeToString(encrypted, Base64.NO_WRAP))
            .putString(KEY_IV, Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .apply()
    }

    fun load(): String {
        val encrypted = preferences.getString(KEY_CIPHERTEXT, null)
            ?: throw IllegalStateException(
                "生体認証ログインが未設定です。パスワードでログインしてください。",
            )
        val iv = preferences.getString(KEY_IV, null)
            ?: throw IllegalStateException(
                "生体認証ログインが未設定です。パスワードでログインしてください。",
            )
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(
            Cipher.DECRYPT_MODE,
            getOrCreateKey(),
            GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)),
        )
        return cipher.doFinal(Base64.decode(encrypted, Base64.NO_WRAP))
            .toString(Charsets.UTF_8)
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            KEYSTORE_PROVIDER,
        ).run {
            init(
                KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .build(),
            )
            generateKey()
        }
    }

    private companion object {
        const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        const val KEY_ALIAS = "org_portal_next_refresh_token"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val KEY_CIPHERTEXT = "ciphertext"
        const val KEY_IV = "iv"
    }
}
