package jp.komehyappyo.member.next.core.model

import java.time.Instant
import java.time.LocalDate
import java.util.UUID

data class FriendContact(
    val id: UUID = UUID.randomUUID(),
    val userId: String,
    val name: String,
    val postalCode: String = "",
    val prefecture: String = "",
    val city: String = "",
    val addressLine: String = "",
    val birthDate: LocalDate? = null,
    val phoneNumber: String = "",
    val email: String = "",
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
) {
    fun validated(now: Instant = Instant.now()): FriendContact {
        require(name.trim().isNotEmpty()) { "名前を入力してください。" }
        return copy(
            name = name.trim(),
            postalCode = postalCode.trim(),
            prefecture = prefecture.trim(),
            city = city.trim(),
            addressLine = addressLine.trim(),
            phoneNumber = phoneNumber.trim(),
            email = email.trim(),
            updatedAt = now,
        )
    }
}

data class FriendInteractionHistory(
    val id: UUID = UUID.randomUUID(),
    val friendId: UUID,
    val interactionDate: Instant = Instant.now(),
    val memo: String = "",
    val photoUrls: List<String> = emptyList(),
    val isPhoneCall: Boolean = false,
    val phoneNumber: String = "",
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
) {
    fun validated(now: Instant = Instant.now()): FriendInteractionHistory {
        require(photoUrls.size <= MAXIMUM_PHOTO_COUNT) {
            "写真は${MAXIMUM_PHOTO_COUNT}枚まで登録できます。"
        }
        require(memo.trim().isNotEmpty() || photoUrls.isNotEmpty() || isPhoneCall) {
            "メモ・写真・電話記録のいずれかを入力してください。"
        }
        return copy(
            memo = memo.trim(),
            phoneNumber = phoneNumber.trim(),
            updatedAt = now,
        )
    }

    companion object {
        const val MAXIMUM_PHOTO_COUNT = 2
    }
}
