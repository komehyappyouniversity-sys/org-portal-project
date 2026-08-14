package jp.komehyappyo.member.next.core.data

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import jp.komehyappyo.member.next.core.model.VideoRepeatSetting
import java.nio.charset.StandardCharsets
import java.security.KeyStore
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

interface VideoRepeatSettingRepository {
    suspend fun setting(videoId: String): VideoRepeatSetting?
    suspend fun save(setting: VideoRepeatSetting)
}

fun interface GuestUserIdProvider {
    fun guestUserId(): String
}

class AndroidKeystoreGuestUserIdProvider(context: Context) : GuestUserIdProvider {
    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )

    @Synchronized
    override fun guestUserId(): String {
        read()?.let { return it }

        val generated = UUID.randomUUID().toString()
        val cipher = Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.ENCRYPT_MODE, secretKey())
        }
        val encrypted = cipher.doFinal(generated.toByteArray(StandardCharsets.UTF_8))
        check(
            preferences.edit()
                .putString(KEY_CIPHERTEXT, Base64.encodeToString(encrypted, Base64.NO_WRAP))
                .putString(KEY_INITIALIZATION_VECTOR, Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
                .commit(),
        ) { "Guest user ID could not be stored." }
        return generated
    }

    private fun read(): String? {
        val encryptedValue = preferences.getString(KEY_CIPHERTEXT, null) ?: return null
        val initializationVector = preferences.getString(KEY_INITIALIZATION_VECTOR, null) ?: return null
        return runCatching {
            val cipher = Cipher.getInstance(TRANSFORMATION).apply {
                init(
                    Cipher.DECRYPT_MODE,
                    secretKey(),
                    GCMParameterSpec(
                        GCM_TAG_LENGTH_BITS,
                        Base64.decode(initializationVector, Base64.NO_WRAP),
                    ),
                )
            }
            String(
                cipher.doFinal(Base64.decode(encryptedValue, Base64.NO_WRAP)),
                StandardCharsets.UTF_8,
            ).takeIf { UUID.fromString(it).toString() == it }
        }.getOrNull()
    }

    private fun secretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }

        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE_PROVIDER).run {
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
        const val PREFERENCES_NAME = "secure_guest_identity"
        const val KEY_CIPHERTEXT = "guest_user_id_ciphertext"
        const val KEY_INITIALIZATION_VECTOR = "guest_user_id_iv"
        const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        const val KEY_ALIAS = "org_portal_next_guest_user_id"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val GCM_TAG_LENGTH_BITS = 128
    }
}
