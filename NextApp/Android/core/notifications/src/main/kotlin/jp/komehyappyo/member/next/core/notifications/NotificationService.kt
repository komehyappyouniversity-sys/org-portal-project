package jp.komehyappyo.member.next.core.notifications

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.net.Uri
import androidx.core.content.ContextCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import jp.komehyappyo.member.next.core.model.Schedule
import java.net.HttpURLConnection
import java.net.URI
import java.security.MessageDigest
import java.time.Instant
import java.util.concurrent.CopyOnWriteArraySet
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import org.json.JSONObject
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

data class FcmToken(
    val id: String,
    val userId: String,
    val token: String,
    val appVariant: String = "next",
    val os: String = "Android",
    val environment: String,
    val updatedAt: Instant,
) {
    companion object {
        fun idFor(token: String): String = MessageDigest.getInstance("SHA-256")
            .digest(token.toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }
    }
}

enum class NotificationType(val payloadValue: String, val host: String) {
    Announcement("announcement", "announcements"),
    AdminReply("admin_reply", "posts"),
    VideoQuestionAnswer("video_question_answer", "video-questions"),
    Event("event", "events"),
    SupportMessage("support_message", "support"),
}

data class NotificationRoute(
    val type: NotificationType,
    val targetId: String,
    val communityId: String? = null,
)

data class NotificationNavigationDecision(
    val route: NotificationRoute,
    val communityIdToSelect: String?,
) {
    companion object {
        fun resolve(route: NotificationRoute, selectedCommunityId: String?): NotificationNavigationDecision =
            NotificationNavigationDecision(
                route = route,
                communityIdToSelect = route.communityId?.takeIf { it != selectedCommunityId },
            )
    }
}

object NotificationRouteParser {
    const val TYPE_EXTRA = "notificationType"
    const val DEEP_LINK_EXTRA = "deepLink"
    const val COMMUNITY_ID_EXTRA = "communityId"
    private val targetKeys = mapOf(
        NotificationType.Announcement to "announcementId",
        NotificationType.AdminReply to "postId",
        NotificationType.VideoQuestionAnswer to "questionId",
        NotificationType.Event to "eventId",
        NotificationType.SupportMessage to "supportMessageId",
    )

    fun uri(route: NotificationRoute): Uri {
        val path = if (route.type == NotificationType.SupportMessage) {
            "messages/${route.targetId}"
        } else {
            route.targetId
        }
        return Uri.Builder()
            .scheme("orgportalnext")
            .authority(route.type.host)
            .path(path)
            .apply { route.communityId?.let { appendQueryParameter(COMMUNITY_ID_EXTRA, it) } }
            .build()
    }

    fun route(intent: Intent?): NotificationRoute? {
        if (intent == null) return null
        intent.getStringExtra(DEEP_LINK_EXTRA)?.let { value ->
            route(Uri.parse(value))?.let { return it }
        }
        route(intent.data)?.let { return it }
        val type = NotificationType.entries.firstOrNull {
            it.payloadValue == intent.getStringExtra(TYPE_EXTRA)
        } ?: return null
        val targetId = intent.getStringExtra(targetKeys.getValue(type))
            ?: intent.getStringExtra("targetId")
        return targetId?.takeIf(String::isNotBlank)?.let {
            NotificationRoute(type, it, intent.getStringExtra(COMMUNITY_ID_EXTRA)?.takeIf(String::isNotBlank))
        }
    }

    fun route(uri: Uri?): NotificationRoute? {
        if (uri?.scheme != "orgportalnext") return null
        val type = NotificationType.entries.firstOrNull { it.host == uri.host } ?: return null
        val segments = uri.pathSegments
        val targetId = when (type) {
            NotificationType.SupportMessage -> segments.takeIf {
                it.size == 2 && it[0] == "messages"
            }?.get(1)
            else -> segments.singleOrNull()
        }?.takeIf(String::isNotBlank) ?: return null
        return NotificationRoute(
            type = type,
            targetId = targetId,
            communityId = uri.getQueryParameter(COMMUNITY_ID_EXTRA)?.takeIf(String::isNotBlank),
        )
    }

    fun putExtras(intent: Intent, route: NotificationRoute): Intent = intent.apply {
        putExtra(TYPE_EXTRA, route.type.payloadValue)
        putExtra(targetKeys.getValue(route.type), route.targetId)
        route.communityId?.let { putExtra(COMMUNITY_ID_EXTRA, it) }
        data = uri(route)
    }
}

object SupportNotificationRoute {
    const val MESSAGE_ID_EXTRA = "supportMessageId"
    const val TYPE_EXTRA = NotificationRouteParser.TYPE_EXTRA
    const val TYPE_VALUE = "support_message"

    fun uri(messageId: String): Uri = NotificationRouteParser.uri(
        NotificationRoute(NotificationType.SupportMessage, messageId),
    )

    fun messageId(intent: Intent?): String? {
        intent?.getStringExtra(MESSAGE_ID_EXTRA)?.takeIf(String::isNotBlank)?.let { return it }
        return NotificationRouteParser.route(intent)
            ?.takeIf { it.type == NotificationType.SupportMessage }
            ?.targetId
    }
}

interface FcmTokenStore {
    suspend fun save(token: FcmToken, idToken: String)
    suspend fun delete(userId: String, tokenId: String, idToken: String)
}

fun interface FcmRegistrationTokenProvider {
    suspend fun currentToken(): String
}

object FirebaseMessagingRuntime {
    fun configure(
        context: Context,
        projectId: String,
        apiKey: String,
        applicationId: String,
        senderId: String,
    ): Boolean {
        if (FirebaseApp.getApps(context).isNotEmpty()) return true
        if (applicationId.isBlank() || senderId.isBlank()) return false
        val options = FirebaseOptions.Builder()
            .setProjectId(projectId)
            .setApiKey(apiKey)
            .setApplicationId(applicationId)
            .setGcmSenderId(senderId)
            .build()
        FirebaseApp.initializeApp(context, options)
        return true
    }

    fun setAutoInitEnabled(enabled: Boolean) {
        FirebaseMessaging.getInstance().isAutoInitEnabled = enabled
    }
}

class FirebaseRegistrationTokenProvider : FcmRegistrationTokenProvider {
    override suspend fun currentToken(): String = suspendCancellableCoroutine { continuation ->
        FirebaseMessaging.getInstance().token
            .addOnSuccessListener { continuation.resume(it) }
            .addOnFailureListener { continuation.resumeWithException(it) }
    }
}

class FcmTokenRegistrationManager(
    private val store: FcmTokenStore,
    private val tokenProvider: FcmRegistrationTokenProvider,
    private val environment: String,
    private val now: () -> Instant = Instant::now,
) {
    private data class Registration(val userId: String, val idToken: String, val tokenId: String)
    private var registration: Registration? = null

    suspend fun synchronize(userId: String?, idToken: String?) {
        if (userId.isNullOrBlank() || userId == "guest" || idToken.isNullOrBlank()) {
            registration?.let { store.delete(it.userId, it.tokenId, it.idToken) }
            registration = null
            return
        }
        registration?.takeIf { it.userId != userId }?.let {
            store.delete(it.userId, it.tokenId, it.idToken)
            registration = null
        }
        register(userId, idToken, tokenProvider.currentToken())
    }

    suspend fun tokenRefreshed(token: String) {
        val current = registration ?: return
        register(current.userId, current.idToken, token)
        if (current.tokenId != FcmToken.idFor(token)) {
            store.delete(current.userId, current.tokenId, current.idToken)
        }
    }

    private suspend fun register(userId: String, idToken: String, rawToken: String) {
        if (rawToken.isBlank()) return
        val token = FcmToken(
            id = FcmToken.idFor(rawToken),
            userId = userId,
            token = rawToken,
            environment = environment,
            updatedAt = now(),
        )
        store.save(token, idToken)
        registration = Registration(userId, idToken, token.id)
    }
}

class FirestoreFcmTokenStore(private val projectId: String) : FcmTokenStore {
    override suspend fun save(token: FcmToken, idToken: String) {
        request(token.userId, token.id, "PATCH", idToken, token.firestoreBody())
    }

    override suspend fun delete(userId: String, tokenId: String, idToken: String) {
        request(userId, tokenId, "DELETE", idToken, null)
    }

    private suspend fun request(
        userId: String,
        tokenId: String,
        method: String,
        idToken: String,
        body: JSONObject?,
    ) = withContext(Dispatchers.IO) {
        val encodedUser = Uri.encode(userId)
        val encodedToken = Uri.encode(tokenId)
        val url = URI(
            "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/" +
                "memberPrivate/$encodedUser/fcmTokens/$encodedToken",
        ).toURL()
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = method
            setRequestProperty("Authorization", "Bearer $idToken")
            setRequestProperty("Content-Type", "application/json")
            connectTimeout = 15_000
            readTimeout = 15_000
            if (body != null) {
                doOutput = true
                outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            }
        }
        val status = connection.responseCode
        if (status !in 200..299 && !(method == "DELETE" && status == 404)) {
            val message = connection.errorStream?.bufferedReader()?.use { it.readText() }
            error("FCM token Firestore request failed ($status): ${message.orEmpty()}")
        }
        connection.disconnect()
    }

    private fun FcmToken.firestoreBody(): JSONObject = JSONObject().put(
        "fields",
        JSONObject()
            .put("id", stringValue(id))
            .put("userId", stringValue(userId))
            .put("token", stringValue(token))
            .put("appVariant", stringValue(appVariant))
            .put("os", stringValue(os))
            .put("environment", stringValue(environment))
            .put("updatedAt", JSONObject().put("timestampValue", updatedAt.toString())),
    )

    private fun stringValue(value: String) = JSONObject().put("stringValue", value)
}

object FcmTokenRefreshBus {
    private val listeners = CopyOnWriteArraySet<(String) -> Unit>()
    fun add(listener: (String) -> Unit) { listeners += listener }
    fun remove(listener: (String) -> Unit) { listeners -= listener }
    fun publish(token: String) { listeners.forEach { it(token) } }
}

class NextFirebaseMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        super.onNewToken(token)
        FcmTokenRefreshBus.publish(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val route = route(message.data) ?: return
        NotificationService(this).showRemoteNotification(
            route = route,
            title = message.notification?.title ?: "次期会員アプリ",
            body = message.notification?.body ?: "新しいお知らせがあります。",
        )
    }

    private fun route(data: Map<String, String>): NotificationRoute? {
        val intent = Intent()
        data.forEach { (key, value) -> intent.putExtra(key, value) }
        return NotificationRouteParser.route(intent)
    }
}

class NotificationService(private val context: Context) {
    fun hasPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED

    fun scheduleReminder(schedule: Schedule) {
        val reminder = schedule.reminderSetting?.takeIf { it.isEnabled } ?: return
        val triggerAt = schedule.startDateTime
            .minusSeconds(reminder.notifyBeforeMinutes * 60L)
            .toEpochMilli()
        if (triggerAt <= System.currentTimeMillis()) return

        val intent = Intent(context, ScheduleReminderReceiver::class.java)
            .putExtra("title", schedule.title)
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            schedule.id.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
    }

    @android.annotation.SuppressLint("MissingPermission")
    fun showRemoteNotification(route: NotificationRoute, title: String, body: String) {
        if (!hasPermission()) return
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: return
        NotificationRouteParser.putExtras(launchIntent, route)
        val pendingIntent = PendingIntent.getActivity(
            context,
            route.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val manager = context.getSystemService(android.app.NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                android.app.NotificationChannel(
                    REMOTE_CHANNEL_ID,
                    "お知らせ",
                    android.app.NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
        val notification = androidx.core.app.NotificationCompat.Builder(context, REMOTE_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        androidx.core.app.NotificationManagerCompat.from(context)
            .notify(route.hashCode(), notification)
    }

    fun showSupportMessageNotification(messageId: String) {
        showRemoteNotification(
            route = NotificationRoute(NotificationType.SupportMessage, messageId),
            title = "サポート",
            body = "サポートから新しいメッセージがあります",
        )
    }

    private companion object {
        const val REMOTE_CHANNEL_ID = "remote_notifications"
    }
}
