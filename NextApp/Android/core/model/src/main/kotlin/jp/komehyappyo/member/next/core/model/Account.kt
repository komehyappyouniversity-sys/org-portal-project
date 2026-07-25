package jp.komehyappyo.member.next.core.model

enum class AccountAccessState {
    Guest,
    PendingApproval,
    Rejected,
    Member,
}

data class AccountCredentials(
    val email: String,
    val password: String,
    val passwordConfirmation: String? = null,
) {
    fun validationError(): String? {
        val normalizedEmail = email.trim()
        if (!EMAIL_PATTERN.matches(normalizedEmail)) {
            return "メールアドレスの形式を確認してください。"
        }
        if (password.length < MINIMUM_PASSWORD_LENGTH) {
            return "パスワードは8文字以上で入力してください。"
        }
        if (passwordConfirmation != null && password != passwordConfirmation) {
            return "確認用パスワードが一致しません。"
        }
        return null
    }

    companion object {
        const val MINIMUM_PASSWORD_LENGTH = 8
        private val EMAIL_PATTERN = Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
    }
}
