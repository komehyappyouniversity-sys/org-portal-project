package jp.komehyappyo.member.next.core.data

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import jp.komehyappyo.member.next.core.model.UsageLog
import jp.komehyappyo.member.next.core.model.UsageLogEventType
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import org.json.JSONObject
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

private val Context.usageAnalyticsDataStore by preferencesDataStore(
    name = "usage_analytics_preferences",
)

interface UsageAnalyticsPreferenceStore {
    val optOutFlow: Flow<Boolean>
    suspend fun isOptedOut(): Boolean
    suspend fun setOptedOut(optedOut: Boolean)
}

class DataStoreUsageAnalyticsPreferenceStore(context: Context) :
    UsageAnalyticsPreferenceStore {
    private val dataStore = context.applicationContext.usageAnalyticsDataStore
    private val optOutKey = booleanPreferencesKey("usageAnalyticsOptOut")

    override val optOutFlow: Flow<Boolean> = dataStore.data.map { preferences ->
        preferences[optOutKey] ?: false
    }

    override suspend fun isOptedOut(): Boolean = optOutFlow.first()

    override suspend fun setOptedOut(optedOut: Boolean) {
        dataStore.edit { preferences -> preferences[optOutKey] = optedOut }
    }
}

interface UsageLogRemoteRepository {
    suspend fun saveUsageLog(log: UsageLog, idToken: String): Result<Unit>
}

class UsageLogRecorder(
    private val remoteRepository: UsageLogRemoteRepository,
    private val preferenceStore: UsageAnalyticsPreferenceStore,
    private val idProvider: () -> String = { UUID.randomUUID().toString() },
    private val now: () -> Instant = Instant::now,
) {
    suspend fun record(
        userId: String,
        idToken: String,
        eventType: UsageLogEventType,
        targetId: String,
        positionSeconds: Double = 0.0,
    ): Boolean {
        if (preferenceStore.isOptedOut()) return false
        val log = UsageLog(
            id = idProvider(),
            userId = userId,
            eventType = eventType,
            targetId = targetId,
            positionSeconds = positionSeconds,
            occurredAt = now(),
        )
        log.validate()
        remoteRepository.saveUsageLog(log, idToken).getOrThrow()
        return true
    }
}

object UsageLogRetention {
    const val NormalEventDays: Long = 90
}

internal fun usageLogFirestoreFields(log: UsageLog): JSONObject {
    log.validate()
    return JSONObject()
        .put("id", JSONObject().put("stringValue", log.id))
        .put("userId", JSONObject().put("stringValue", log.userId))
        .put("eventType", JSONObject().put("stringValue", log.eventType.rawValue))
        .put("targetId", JSONObject().put("stringValue", log.targetId))
        .put("positionSeconds", JSONObject().put("doubleValue", log.positionSeconds))
        .put("occurredAt", JSONObject().put("timestampValue", log.occurredAt.toString()))
        .put(
            "expiresAt",
            JSONObject().put(
                "timestampValue",
                log.occurredAt.plus(UsageLogRetention.NormalEventDays, ChronoUnit.DAYS).toString(),
            ),
        )
}
