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
            AccountCredentials("member@example.com", "password", "different")
                .validationError(),
        )
    }
}
