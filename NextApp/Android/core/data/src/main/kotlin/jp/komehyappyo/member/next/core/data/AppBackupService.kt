package jp.komehyappyo.member.next.core.data

import android.util.Base64
import jp.komehyappyo.member.next.core.model.FriendContact
import jp.komehyappyo.member.next.core.model.FriendInteractionHistory
import jp.komehyappyo.member.next.core.model.MeetingMinutes
import jp.komehyappyo.member.next.core.model.RecurrenceFrequency
import jp.komehyappyo.member.next.core.model.RecurrenceRule
import jp.komehyappyo.member.next.core.model.ReminderSetting
import jp.komehyappyo.member.next.core.model.Schedule
import jp.komehyappyo.member.next.core.model.ScheduleCategory
import jp.komehyappyo.member.next.core.model.ScheduleTimeOfDay
import jp.komehyappyo.member.next.core.model.SnsCustomLink
import kotlinx.coroutines.flow.first
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

data class AppBackupImportSummary(
    val schedules: Int,
    val diaries: Int,
    val cashDistributions: Int,
    val meetingMinutes: Int,
    val snsLinks: Int,
    val favorites: Int,
    val friendContacts: Int,
    val friendHistories: Int,
) {
    val total: Int
        get() = schedules + diaries + cashDistributions + meetingMinutes + snsLinks + favorites +
            friendContacts + friendHistories
}

data class AppBackupExportResult(
    val data: ByteArray,
    val skippedMeetingMinutes: Int,
)

/**
 * アプリ削除前に必要な端末内データを、iPhone/Android共通の1ファイルへまとめます。
 * Firebase上の会員・コミュニティ情報は対象外です。
 */
class AppBackupService(
    private val scheduleRepository: ScheduleRepository,
    diaryRepository: DiaryRepository,
    photoStore: DiaryPhotoStore,
    cashDistributionRepository: CashDistributionRepository,
    private val meetingMinutesRepository: MeetingMinutesRepository,
    private val recordingStore: LocalMeetingRecordingStore,
    private val snsCustomLinkRepository: SnsCustomLinkRepository,
    favoriteBookmarkRepository: FavoriteBookmarkRepository,
    private val friendExchangeRepository: FriendExchangeRepository,
) {
    private val diaryService = DiaryBackupService(diaryRepository, photoStore)
    private val cashService = CashDistributionBackupService(cashDistributionRepository)
    private val favoriteService = FavoriteBookmarkBackupService(favoriteBookmarkRepository)

    suspend fun exportData(now: Instant = Instant.now()): AppBackupExportResult {
        var skippedMeetingMinutes = 0
        val schedules = JSONArray().also { array ->
            scheduleRepository.observeAll().first().forEach { schedule ->
                array.put(JSONObject().put("value", schedule.toBackupJson()))
            }
        }
        val minutes = JSONArray().also { array ->
            meetingMinutesRepository.observeAll().first().forEach { value ->
                val audioFile = File(value.audioFileLocalPath)
                val audio = audioFile
                    .takeIf(File::isFile)
                    ?.let { file -> runCatching { file.readBytes() }.getOrNull() }
                    ?.takeIf { it.isNotEmpty() && it.size <= MAXIMUM_AUDIO_BYTES }
                if (audio == null) {
                    skippedMeetingMinutes += 1
                    return@forEach
                }
                val pdf = value.pdfFileLocalPath
                    ?.let(::File)
                    ?.takeIf(File::isFile)
                    ?.let { file -> runCatching { file.readBytes() }.getOrNull() }
                    ?.takeIf { it.isNotEmpty() && it.size <= MAXIMUM_PDF_BYTES }
                array.put(
                    JSONObject()
                        .put("id", value.id.toString())
                        .put("userId", value.userId)
                        .put("title", value.title)
                        .put("recordingStartAtEpochMillis", value.recordingStartAt.toEpochMilli())
                        .put("recordingEndAtEpochMillis", value.recordingEndAt.toEpochMilli())
                        .put("recordingDurationSeconds", value.recordingDurationSeconds)
                        .put("transcriptText", value.transcriptText)
                        .put("createdAtEpochMillis", value.createdAt.toEpochMilli())
                        .put("updatedAtEpochMillis", value.updatedAt.toEpochMilli())
                        .put("audioDataBase64", encode(audio))
                        .put("audioSha256", sha256(audio))
                        .put("pdfDataBase64", pdf?.let(::encode) ?: JSONObject.NULL)
                        .put("pdfSha256", pdf?.let(::sha256) ?: JSONObject.NULL),
                )
            }
        }
        val snsLinks = JSONArray().also { array ->
            snsCustomLinkRepository.observeAll().first().forEach { link ->
                array.put(
                    JSONObject().put(
                        "value",
                        JSONObject()
                            .put("id", link.id.toString())
                            .put("userId", link.userId)
                            .put("title", link.title)
                            .put("url", link.url)
                            .put("sortOrder", link.sortOrder),
                    ),
                )
            }
        }
        val friendContacts = friendExchangeRepository.observeContacts().first()
        val friendContactEntries = JSONArray().also { array ->
            friendContacts.forEach { contact -> array.put(contact.toBackupJson()) }
        }
        val friendHistoryEntries = JSONArray().also { array ->
            friendContacts.forEach { contact ->
                friendExchangeRepository.observeHistories(contact.id).first()
                    .forEach { history -> array.put(history.toBackupJson()) }
            }
        }
        val data = JSONObject()
            .put("format", FORMAT_IDENTIFIER)
            .put("version", CURRENT_VERSION)
            .put("exportedAtEpochMillis", now.toEpochMilli())
            .put("diaryBackupBase64", encode(diaryService.exportData(now)))
            .put("cashDistributionBackupBase64", encode(cashService.exportData(now)))
            .put("favoriteBookmarkBackupBase64", encode(favoriteService.exportData(now)))
            .put("schedules", schedules)
            .put("meetingMinutes", minutes)
            .put("snsCustomLinks", snsLinks)
            .put("friendContacts", friendContactEntries)
            .put("friendInteractionHistories", friendHistoryEntries)
            .toString(2)
            .toByteArray(Charsets.UTF_8)
        return AppBackupExportResult(
            data = data,
            skippedMeetingMinutes = skippedMeetingMinutes,
        )
    }

    suspend fun importData(data: ByteArray): AppBackupImportSummary {
        val root = runCatching { JSONObject(data.toString(Charsets.UTF_8)) }
            .getOrElse { throw AppBackupException.InvalidFormat }
        if (root.optString("format") != FORMAT_IDENTIFIER) {
            throw AppBackupException.InvalidFormat
        }
        if (root.optInt("version") != CURRENT_VERSION) {
            throw AppBackupException.UnsupportedVersion
        }
        val schedules = root.optJSONArray("schedules")
            ?: throw AppBackupException.InvalidFormat
        val minutes = root.optJSONArray("meetingMinutes")
            ?: throw AppBackupException.InvalidFormat
        val links = root.optJSONArray("snsCustomLinks")
            ?: throw AppBackupException.InvalidFormat
        val friendContacts = root.optJSONArray("friendContacts") ?: JSONArray()
        val friendHistories = root.optJSONArray("friendInteractionHistories") ?: JSONArray()
        val diaryData = decode(root.optString("diaryBackupBase64"))
        val cashData = decode(root.optString("cashDistributionBackupBase64"))
        val favoriteData = decode(root.optString("favoriteBookmarkBackupBase64"))

        val diaryCount = diaryService.importData(diaryData)
        val cashCount = cashService.importData(cashData)
        val favoriteCount = favoriteService.importData(favoriteData)

        repeat(schedules.length()) { index ->
            val value = schedules.optJSONObject(index)?.optJSONObject("value")
                ?: throw AppBackupException.InvalidFormat
            scheduleRepository.save(value.toSchedule())
        }
        repeat(links.length()) { index ->
            val value = links.optJSONObject(index)?.optJSONObject("value")
                ?: throw AppBackupException.InvalidFormat
            val link = runCatching {
                SnsCustomLink(
                    id = UUID.fromString(value.getString("id")),
                    userId = value.optString("userId", "guest-local"),
                    title = value.getString("title"),
                    url = value.getString("url"),
                    sortOrder = value.optInt("sortOrder"),
                ).validated()
            }.getOrElse { throw AppBackupException.InvalidFormat }
            snsCustomLinkRepository.save(link)
        }
        repeat(minutes.length()) { index ->
            restoreMeeting(
                minutes.optJSONObject(index) ?: throw AppBackupException.InvalidFormat,
            )
        }
        val importedFriendIds = mutableSetOf<UUID>()
        repeat(friendContacts.length()) { index ->
            val contact = friendContacts.optJSONObject(index)?.toFriendContact()
                ?: throw AppBackupException.InvalidFormat
            friendExchangeRepository.save(contact)
            importedFriendIds.add(contact.id)
        }
        repeat(friendHistories.length()) { index ->
            val history = friendHistories.optJSONObject(index)?.toFriendHistory()
                ?: throw AppBackupException.InvalidFormat
            if (history.friendId !in importedFriendIds) {
                throw AppBackupException.InvalidFormat
            }
            friendExchangeRepository.save(history)
        }
        return AppBackupImportSummary(
            schedules = schedules.length(),
            diaries = diaryCount,
            cashDistributions = cashCount,
            meetingMinutes = minutes.length(),
            snsLinks = links.length(),
            favorites = favoriteCount,
            friendContacts = friendContacts.length(),
            friendHistories = friendHistories.length(),
        )
    }

    private fun FriendContact.toBackupJson(): JSONObject = JSONObject()
        .put("id", id.toString())
        .put("userId", userId)
        .put("name", name)
        .put("postalCode", postalCode)
        .put("prefecture", prefecture)
        .put("city", city)
        .put("addressLine", addressLine)
        .put("birthDate", birthDate?.toString() ?: JSONObject.NULL)
        .put("phoneNumber", phoneNumber)
        .put("email", email)
        .put("createdAtEpochMillis", createdAt.toEpochMilli())
        .put("updatedAtEpochMillis", updatedAt.toEpochMilli())

    private fun FriendInteractionHistory.toBackupJson(): JSONObject = JSONObject()
        .put("id", id.toString())
        .put("friendId", friendId.toString())
        .put("interactionDateEpochMillis", interactionDate.toEpochMilli())
        .put("memo", memo)
        .put("photoUrls", JSONArray(photoUrls))
        .put("isPhoneCall", isPhoneCall)
        .put("phoneNumber", phoneNumber)
        .put("createdAtEpochMillis", createdAt.toEpochMilli())
        .put("updatedAtEpochMillis", updatedAt.toEpochMilli())

    private fun JSONObject.toFriendContact(): FriendContact = runCatching {
        val updatedAt = Instant.ofEpochMilli(getLong("updatedAtEpochMillis"))
        FriendContact(
            id = UUID.fromString(getString("id")),
            userId = optString("userId", "guest-local"),
            name = getString("name"),
            postalCode = optString("postalCode"),
            prefecture = optString("prefecture"),
            city = optString("city"),
            addressLine = optString("addressLine"),
            birthDate = if (isNull("birthDate")) {
                null
            } else {
                optString("birthDate").takeIf(String::isNotBlank)?.let(LocalDate::parse)
            },
            phoneNumber = optString("phoneNumber"),
            email = optString("email"),
            createdAt = Instant.ofEpochMilli(getLong("createdAtEpochMillis")),
            updatedAt = updatedAt,
        ).validated(now = updatedAt)
    }.getOrElse { throw AppBackupException.InvalidFormat }

    private fun JSONObject.toFriendHistory(): FriendInteractionHistory = runCatching {
        val updatedAt = Instant.ofEpochMilli(getLong("updatedAtEpochMillis"))
        val photos = optJSONArray("photoUrls") ?: JSONArray()
        FriendInteractionHistory(
            id = UUID.fromString(getString("id")),
            friendId = UUID.fromString(getString("friendId")),
            interactionDate = Instant.ofEpochMilli(getLong("interactionDateEpochMillis")),
            memo = optString("memo"),
            photoUrls = buildList {
                repeat(photos.length()) { index -> add(photos.getString(index)) }
            },
            isPhoneCall = optBoolean("isPhoneCall"),
            phoneNumber = optString("phoneNumber"),
            createdAt = Instant.ofEpochMilli(getLong("createdAtEpochMillis")),
            updatedAt = updatedAt,
        ).validated(now = updatedAt)
    }.getOrElse { throw AppBackupException.InvalidFormat }

    private suspend fun restoreMeeting(entry: JSONObject) {
        val id = runCatching { UUID.fromString(entry.getString("id")) }
            .getOrElse { throw AppBackupException.InvalidFormat }
        val audio = decode(entry.optString("audioDataBase64"))
        if (
            audio.isEmpty() ||
            audio.size > MAXIMUM_AUDIO_BYTES ||
            sha256(audio) != entry.optString("audioSha256")
        ) {
            throw AppBackupException.InvalidAttachment
        }
        val audioFile = recordingStore.permanentAudioFile(id)
        writeAtomically(audioFile, audio)

        val pdfData = if (entry.isNull("pdfDataBase64")) {
            null
        } else {
            decode(entry.getString("pdfDataBase64"))
        }
        val pdfFile = pdfData?.let { bytes ->
            if (
                bytes.isEmpty() ||
                bytes.size > MAXIMUM_PDF_BYTES ||
                sha256(bytes) != entry.optString("pdfSha256")
            ) {
                throw AppBackupException.InvalidAttachment
            }
            File(audioFile.parentFile, "$id.pdf").also { writeAtomically(it, bytes) }
        }
        val minutes = runCatching {
            MeetingMinutes(
                id = id,
                userId = entry.optString("userId", "guest"),
                title = entry.getString("title"),
                recordingStartAt = Instant.ofEpochMilli(
                    entry.getLong("recordingStartAtEpochMillis"),
                ),
                recordingEndAt = Instant.ofEpochMilli(
                    entry.getLong("recordingEndAtEpochMillis"),
                ),
                recordingDurationSeconds = entry.getInt("recordingDurationSeconds"),
                audioFileLocalPath = audioFile.absolutePath,
                transcriptText = entry.optString("transcriptText"),
                pdfFileLocalPath = pdfFile?.absolutePath,
                createdAt = Instant.ofEpochMilli(entry.getLong("createdAtEpochMillis")),
                updatedAt = Instant.ofEpochMilli(entry.getLong("updatedAtEpochMillis")),
            )
        }.getOrElse { throw AppBackupException.InvalidFormat }
        meetingMinutesRepository.save(minutes)
    }

    private fun Schedule.toBackupJson(): JSONObject = JSONObject()
        .put("id", id.toString())
        .put("userId", userId)
        .put("title", title)
        .put("startDateTime", startDateTime.toEpochMilli())
        .put("endDateTime", endDateTime.toEpochMilli())
        .put("location", location)
        .put("timeOfDay", timeOfDay.backupValue)
        .put("memo", memo)
        .put("isCompleted", isCompleted)
        .put(
            "recurrenceRule",
            recurrenceRule?.let {
                JSONObject()
                    .put("frequency", it.frequency.backupValue)
                    .put("interval", it.interval)
                    .put("endDate", it.endDate?.toEpochMilli() ?: JSONObject.NULL)
            } ?: JSONObject.NULL,
        )
        .put(
            "reminderSetting",
            reminderSetting?.let {
                JSONObject()
                    .put("notifyBeforeMinutes", it.notifyBeforeMinutes)
                    .put("isEnabled", it.isEnabled)
            } ?: JSONObject.NULL,
        )
        .put(
            "category",
            category?.let {
                JSONObject()
                    .put("id", it.id.toString())
                    .put("userId", it.userId)
                    .put("name", it.name)
                    .put("colorHex", it.colorHex)
            } ?: JSONObject.NULL,
        )
        .put("createdAt", createdAt.toEpochMilli())
        .put("updatedAt", updatedAt.toEpochMilli())

    private fun JSONObject.toSchedule(): Schedule = runCatching {
        Schedule(
            id = UUID.fromString(getString("id")),
            userId = optString("userId", "guest"),
            title = getString("title"),
            startDateTime = Instant.ofEpochMilli(getLong("startDateTime")),
            endDateTime = Instant.ofEpochMilli(getLong("endDateTime")),
            location = optString("location"),
            timeOfDay = scheduleTimeOfDayFromBackupValue(getString("timeOfDay")),
            memo = optString("memo"),
            isCompleted = optBoolean("isCompleted"),
            recurrenceRule = optJSONObject("recurrenceRule")?.let {
                RecurrenceRule(
                    frequency = recurrenceFrequencyFromBackupValue(it.getString("frequency")),
                    interval = it.optInt("interval", 1),
                    endDate = if (it.isNull("endDate")) {
                        null
                    } else {
                        Instant.ofEpochMilli(it.getLong("endDate"))
                    },
                )
            },
            reminderSetting = optJSONObject("reminderSetting")?.let {
                ReminderSetting(
                    notifyBeforeMinutes = it.getInt("notifyBeforeMinutes"),
                    isEnabled = it.optBoolean("isEnabled", true),
                )
            },
            category = optJSONObject("category")?.let {
                ScheduleCategory(
                    id = UUID.fromString(it.getString("id")),
                    userId = it.optString("userId", "guest"),
                    name = it.getString("name"),
                    colorHex = it.optString("colorHex", "#3F7D58"),
                )
            },
            createdAt = Instant.ofEpochMilli(getLong("createdAt")),
            updatedAt = Instant.ofEpochMilli(getLong("updatedAt")),
        ).validated()
    }.getOrElse { throw AppBackupException.InvalidFormat }

    private fun writeAtomically(destination: File, bytes: ByteArray) {
        destination.parentFile?.mkdirs()
        val temporary = File(destination.parentFile, "${destination.name}.tmp")
        temporary.writeBytes(bytes)
        if (destination.exists() && !destination.delete()) {
            temporary.delete()
            throw AppBackupException.InvalidAttachment
        }
        if (!temporary.renameTo(destination)) {
            temporary.delete()
            throw AppBackupException.InvalidAttachment
        }
    }

    private fun encode(data: ByteArray): String = Base64.encodeToString(data, Base64.NO_WRAP)

    private fun decode(value: String): ByteArray = runCatching {
        Base64.decode(value, Base64.DEFAULT)
    }.getOrElse { throw AppBackupException.InvalidFormat }

    private fun sha256(data: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(data).joinToString("") { "%02x".format(it) }

    private val ScheduleTimeOfDay.backupValue: String
        get() = name.replaceFirstChar(Char::lowercase)

    private val RecurrenceFrequency.backupValue: String
        get() = name.replaceFirstChar(Char::lowercase)

    private fun scheduleTimeOfDayFromBackupValue(value: String): ScheduleTimeOfDay =
        ScheduleTimeOfDay.entries.firstOrNull { it.backupValue == value }
            ?: throw AppBackupException.InvalidFormat

    private fun recurrenceFrequencyFromBackupValue(value: String): RecurrenceFrequency =
        RecurrenceFrequency.entries.firstOrNull { it.backupValue == value }
            ?: throw AppBackupException.InvalidFormat

    companion object {
        const val FORMAT_IDENTIFIER = "org-portal-app-backup"
        const val CURRENT_VERSION = 1
        private const val MAXIMUM_AUDIO_BYTES = 500 * 1_024 * 1_024
        private const val MAXIMUM_PDF_BYTES = 100 * 1_024 * 1_024
    }
}

sealed class AppBackupException : Exception() {
    data object InvalidFormat : AppBackupException()
    data object UnsupportedVersion : AppBackupException()
    data object MissingRecording : AppBackupException()
    data object InvalidAttachment : AppBackupException()
}
