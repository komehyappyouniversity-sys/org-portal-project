package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertNotNull
import kotlin.test.assertNull

class AccountCredentialsTest {
    @Test
    fun validRegistrationInputHasNoError() {
        assertNull(
            AccountCredentials(
                email = "member@example.com",
                password = "password",
                passwordConfirmation = "password",
                name = "根津 孝誠",
                furigana = "ねづ こうせい",
            ).validationError(),
        )
    }

    @Test
    fun invalidEmailIsRejected() {
        assertNotNull(AccountCredentials("invalid", "password").validationError())
    }

    @Test
    fun mismatchedConfirmationIsRejected() {
        assertNotNull(
            AccountCredentials(
                "member@example.com",
                "password",
                "different",
                "根津 孝誠",
                "ねづ こうせい",
            )
                .validationError(),
        )
    }

    @Test
    fun registrationRequiresNameAndFurigana() {
        assertNotNull(
            AccountCredentials(
                email = "member@example.com",
                password = "password",
                passwordConfirmation = "password",
            ).validationError(),
        )
        assertNotNull(
            AccountCredentials(
                email = "member@example.com",
                password = "password",
                passwordConfirmation = "password",
                name = "根津 孝誠",
            ).validationError(),
        )
    }
}
