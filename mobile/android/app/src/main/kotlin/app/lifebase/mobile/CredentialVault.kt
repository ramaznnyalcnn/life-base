package app.lifebase.mobile

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class CredentialVault(context: Context) {
    private val preferences = context.getSharedPreferences("lifebase_native", Context.MODE_PRIVATE)

    fun save(serverUrl: String, token: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        preferences.edit()
            .putString("server_url", serverUrl)
            .putString("token", Base64.encodeToString(cipher.doFinal(token.toByteArray()), Base64.NO_WRAP))
            .putString("token_iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .apply()
    }

    fun serverUrl(): String? = preferences.getString("server_url", null)

    fun token(): String? {
        val encrypted = preferences.getString("token", null) ?: return null
        val iv = preferences.getString("token_iv", null) ?: return null
        return runCatching {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)))
            String(cipher.doFinal(Base64.decode(encrypted, Base64.NO_WRAP)))
        }.getOrNull()
    }

    fun saveWidget(payload: String) = preferences.edit().putString("widget_snapshot", payload).apply()
    fun widget(): String = preferences.getString("widget_snapshot", null).orEmpty()
    fun saveCalendar(id: Long) = preferences.edit().putLong("calendar_id", id).apply()
    fun calendarId(): Long? = preferences.getLong("calendar_id", -1).takeIf { it >= 0 }
    fun mappings() = preferences
    fun clearSession() {
        preferences.edit()
            .remove("server_url")
            .remove("token")
            .remove("token_iv")
            .remove("widget_snapshot")
            .apply()
        KeyStore.getInstance("AndroidKeyStore").apply {
            load(null)
            if (containsAlias(alias)) deleteEntry(alias)
        }
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build())
            generateKey()
        }
    }

    companion object { private const val alias = "lifebase_mobile_credentials" }
}
