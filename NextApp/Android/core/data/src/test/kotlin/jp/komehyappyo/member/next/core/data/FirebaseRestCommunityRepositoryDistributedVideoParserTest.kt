package jp.komehyappyo.member.next.core.data

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FirebaseRestCommunityRepositoryDistributedVideoParserTest {
    @Test
    fun parseDistributedVideoFallsBackWhenRequiredFieldsMissing() {
        val document = JSONObject().apply {
            put("name", "projects/p/databases/(default)/documents/organizations/org-1/videos/")
            put("fields", JSONObject())
        }

        val video = parseDistributedVideo(document, "org-1")

        assertTrue(video.id.isNotBlank())
        assertEquals("Vimeo動画", video.videoTitle)
        assertEquals("", video.description)
        assertEquals("", video.embedHtml)
        assertEquals("", video.videoUrl)
        assertEquals("", video.vimeoUrl)
        assertEquals("", video.providerVideoId)
        assertEquals("distributed_vimeo", video.videoType)
        assertEquals("", video.thumbnailUrl)
        assertEquals(0, video.sortOrder)
        assertEquals("", video.primaryCategoryId)
        assertEquals("", video.secondaryCategoryId)
        assertFalse(video.isPublished)
        assertFalse(video.isMembersOnly)
        assertFalse(video.isPremium)
        assertEquals("", video.createdAt)
        assertEquals("", video.updatedAt)
    }

    @Test
    fun parseDistributedVideoIgnoresUnknownFieldsAndFallsBackToProvider() {
        val fields = JSONObject().apply {
            put("providerVideoId", JSONObject().put("stringValue", "v123"))
            put("title", JSONObject().put("stringValue", "legacy title"))
            put("description", JSONObject().put("stringValue", "desc"))
            put("embedHtml", JSONObject().put("stringValue", "<iframe></iframe>"))
            put("videoUrl", JSONObject().put("stringValue", "https://example.com/video"))
            put("primaryCategoryId", JSONObject().put("stringValue", "cat-main"))
            put("secondaryCategoryId", JSONObject().put("stringValue", "cat-sub"))
            put("isMembersOnly", JSONObject().put("booleanValue", true))
            put("sortOrder", JSONObject().put("integerValue", "42"))
            put("futureField", JSONObject().put("stringValue", "future"))
        }
        val document = JSONObject().apply {
            put("name", "projects/p/databases/(default)/documents/organizations/org-1/videos/video-1")
            put("fields", fields)
        }

        val video = parseDistributedVideo(document, "org-1")

        assertEquals("org-1", video.communityId)
        assertEquals("video-1", video.id)
        assertEquals("legacy title", video.videoTitle)
        assertEquals("desc", video.description)
        assertEquals("<iframe></iframe>", video.embedHtml)
        assertEquals("https://example.com/video", video.videoUrl)
        assertEquals("https://vimeo.com/v123", video.vimeoUrl)
        assertEquals("v123", video.providerVideoId)
        assertTrue(video.isMembersOnly)
        assertEquals(42, video.sortOrder)
        assertEquals("cat-main", video.primaryCategoryId)
        assertEquals("cat-sub", video.secondaryCategoryId)
    }

    @Test
    fun parseDistributedVideoFallsBackCategoryToLegacyField() {
        val fields = JSONObject().apply {
            put("providerVideoId", JSONObject().put("stringValue", "v999"))
            put("category", JSONObject().put("stringValue", "legacy-category"))
            put("vimeoUrl", JSONObject().put("stringValue", "https://vimeo.com/existing"))
        }
        val document = JSONObject().apply {
            put("name", "projects/p/databases/(default)/documents/organizations/org-1/videos/video-legacy")
            put("fields", fields)
        }

        val video = parseDistributedVideo(document, "org-1")

        assertEquals("legacy-category", video.primaryCategoryId)
        assertEquals("", video.secondaryCategoryId)
        assertEquals("https://vimeo.com/v999", video.vimeoUrl)
        assertEquals("v999", video.providerVideoId)
    }
}
