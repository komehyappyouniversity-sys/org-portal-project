package jp.komehyappyo.member.next

import android.app.Application
import com.google.firebase.messaging.FirebaseMessaging
import jp.komehyappyo.member.next.core.data.FirebaseEnvironmentGuard
import jp.komehyappyo.member.next.core.notifications.FirebaseMessagingRuntime

class NextApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        FirebaseEnvironmentGuard.requireSafeDebugProject(
            isDebug = BuildConfig.DEBUG,
            configuredProjectId = BuildConfig.FIREBASE_PROJECT_ID,
        )
        if (
            FirebaseMessagingRuntime.configure(
                context = this,
                projectId = BuildConfig.FIREBASE_PROJECT_ID,
                apiKey = BuildConfig.FIREBASE_WEB_API_KEY,
                applicationId = BuildConfig.FIREBASE_ANDROID_APP_ID,
                senderId = BuildConfig.FIREBASE_GCM_SENDER_ID,
            )
        ) {
            FirebaseMessaging.getInstance().isAutoInitEnabled = true
        }
    }
}
