package jp.komehyappyo.member.next.core.model

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

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

    @Test
    fun communityCodeParserSupportsCodeAndInvitationUrl() {
        assertEquals("k100u", CommunityCodeParser.parse("  K100U  "))
        assertEquals(
            "k100u",
            CommunityCodeParser.parse(
                "https://example.com/community/join?communityCode=K100U",
            ),
        )
        assertEquals(
            "k100u",
            CommunityCodeParser.parse("https://example.com/community/K100U"),
        )
    }

    @Test
    fun communityCodeParserRejectsEmptyOrExcessivelyLongValues() {
        assertNull(CommunityCodeParser.parse("   "))
        assertNull(CommunityCodeParser.parse("a".repeat(101)))
    }

    @Test
    fun publicCommunitySearchMatchesNameCodeAndDescription() {
        val community = Community(
            id = "community-1",
            code = "K100U",
            name = "米百俵大学",
            description = "学び合う公開コミュニティ",
            surfingVisible = true,
        )

        assertTrue(community.matchesPublicSearch(""))
        assertTrue(community.matchesPublicSearch("米百俵"))
        assertTrue(community.matchesPublicSearch("k100u"))
        assertTrue(community.matchesPublicSearch("公開コミュニティ"))
        assertFalse(community.matchesPublicSearch("該当なし"))
        assertTrue(community.surfingVisible)
    }

    @Test
    fun communityAdminAccessSupportsOwnerExplicitAndLegacyPermissions() {
        assertTrue(
            CommunityAdminAccess(
                communityId = "k100u",
                userId = "owner",
                role = "owner",
                permissions = emptySet(),
            ).canReviewMembers,
        )
        assertTrue(
            CommunityAdminAccess(
                communityId = "k100u",
                userId = "manager",
                role = "manager",
                permissions = setOf(CommunityAdminAccess.MEMBER_REVIEW_PERMISSION),
            ).canReviewMembers,
        )
        assertTrue(
            CommunityAdminAccess(
                communityId = "k100u",
                userId = "legacy",
                role = "admin",
                permissions = emptySet(),
                isLegacyFullAccess = true,
            ).canReviewMembers,
        )
        assertFalse(
            CommunityAdminAccess(
                communityId = "k100u",
                userId = "accountant",
                role = "manager",
                permissions = setOf("accountingRead"),
            ).canReviewMembers,
        )
    }

    @Test
    fun communityAdminAccessRejectsExpiredManagerPermission() {
        assertFalse(
            CommunityAdminAccess(
                communityId = "k100u",
                userId = "member",
                role = "manager",
                permissions = setOf("announcementRead"),
            ).canReviewMembers,
        )
    }
}
