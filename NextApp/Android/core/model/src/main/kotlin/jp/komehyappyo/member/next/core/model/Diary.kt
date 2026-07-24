package jp.komehyappyo.member.next.core.model

import java.time.Instant
import java.util.UUID

enum class DiaryMood {
    VeryGood,
    Good,
    Neutral,
    SlightlyBad,
    Bad,
}

data class Diary(
    val id: UUID = UUID.randomUUID(),
    val userId: String,
    val title: String,
    val body: String = "",
    val mood: DiaryMood = DiaryMood.Neutral,
    val photoUrls: List<String> = emptyList(),
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
) {
    fun validated(now: Instant = Instant.now()): Diary {
        require(title.trim().isNotEmpty()) { "タイトルを入力してください。" }
        require(photoUrls.size <= MAXIMUM_PHOTO_COUNT) {
            "写真は${MAXIMUM_PHOTO_COUNT}枚まで登録できます。"
        }
        return copy(
            title = title.trim(),
            body = body.trim(),
            updatedAt = now,
        )
    }

    companion object {
        const val MAXIMUM_PHOTO_COUNT = 5
    }
}
