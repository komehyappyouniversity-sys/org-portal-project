package jp.komehyappyo.member.next.core.data

import java.time.Instant
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class FirebaseRestCommunityRepositoryRadioProgramParserTest {
    @Test
    fun parseRadioProgramMapsFirestoreFields() {
        val document = JSONObject(
            """
            {
              "name": "projects/test/databases/(default)/documents/organizations/org-1/radioPrograms/radio-1",
              "fields": {
                "title": {"stringValue": "朝のラジオ"},
                "description": {"stringValue": "お知らせ番組"},
                "imageUrl": {"stringValue": "https://example.com/radio.jpg"},
                "audioUrl": {"stringValue": "https://example.com/radio.mp3"},
                "broadcastStartAt": {"timestampValue": "2026-08-14T01:00:00Z"},
                "broadcastEndAt": {"timestampValue": "2026-08-14T02:00:00Z"},
                "futureField": {"stringValue": "ignored"}
              }
            }
            """.trimIndent(),
        )

        val program = parseRadioProgram(document, "org-1")

        assertEquals("radio-1", program.id)
        assertEquals("org-1", program.communityId)
        assertEquals("朝のラジオ", program.title)
        assertEquals("お知らせ番組", program.description)
        assertEquals("https://example.com/radio.jpg", program.imageUrl)
        assertEquals("https://example.com/radio.mp3", program.audioUrl)
        assertEquals(Instant.parse("2026-08-14T01:00:00Z"), program.broadcastStartAt)
        assertEquals(Instant.parse("2026-08-14T02:00:00Z"), program.broadcastEndAt)
    }

    @Test
    fun parseRadioProgramFallsBackForMissingAndInvalidFields() {
        val document = JSONObject(
            """
            {
              "name": "",
              "fields": {
                "broadcastStartAt": {"timestampValue": "invalid"}
              }
            }
            """.trimIndent(),
        )

        val program = parseRadioProgram(document, "org-2")

        assertFalse(program.id.isBlank())
        assertEquals("org-2", program.communityId)
        assertEquals("ラジオ番組", program.title)
        assertEquals("", program.description)
        assertEquals("", program.imageUrl)
        assertEquals("", program.audioUrl)
        assertEquals(Instant.EPOCH, program.broadcastStartAt)
        assertEquals(Instant.EPOCH, program.broadcastEndAt)
    }
}
