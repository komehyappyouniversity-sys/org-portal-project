package jp.komehyappyo.member.next.feature.tools

import jp.komehyappyo.member.next.core.model.DistributedVideo
import kotlin.test.Test
import kotlin.test.assertEquals

class DistributedVideoFeatureModelTest {
    @Test
    fun filtersOutMembersOnlyVideoWhenCommunityIsNotAllowed() {
        val sourceVideos = listOf(
            distributedVideo(id = "public", title = "公開動画", sortOrder = 1),
            distributedVideo(id = "member", title = "限定動画", isMembersOnly = true, sortOrder = 0),
            distributedVideo(id = "premium", title = "有料動画", isPremium = true, sortOrder = -1),
            distributedVideo(id = "another", title = "別公開動画", isMembersOnly = false, sortOrder = 2),
        )

        val result = filterDistributedVideos(sourceVideos, canViewMembersOnlyVideo = false)

        assertEquals(listOf("public", "another"), result.map { it.id })
    }

    @Test
    fun showsMembersOnlyVideoForAllowedCommunity() {
        val sourceVideos = listOf(
            distributedVideo(id = "public", title = "公開動画", sortOrder = 2),
            distributedVideo(id = "member", title = "限定動画", isMembersOnly = true, sortOrder = 1),
            distributedVideo(id = "premium", title = "有料動画", isPremium = true, sortOrder = 0),
            distributedVideo(id = "another", title = "別公開動画", sortOrder = 3),
        )

        val result = filterDistributedVideos(sourceVideos, canViewMembersOnlyVideo = true)

        assertEquals(listOf("member", "public", "another"), result.map { it.id })
    }

    @Test
    fun selectsVideoPlaybackSourceInEmbedThenVimeoThenUrlOrder() {
        val embedVideo = distributedVideo(
            id = "a",
            title = "embed",
            sortOrder = 0,
            embedHtml = "<iframe />",
            vimeoUrl = "https://example.com/vimeo",
            videoUrl = "https://example.com/video",
        )
        val vimeoOnlyVideo = distributedVideo(
            id = "b",
            title = "vimeo",
            sortOrder = 1,
            embedHtml = "",
            vimeoUrl = "https://example.com/vimeo",
            videoUrl = "https://example.com/video",
        )
        val urlOnlyVideo = distributedVideo(
            id = "c",
            title = "url",
            sortOrder = 2,
            embedHtml = "",
            vimeoUrl = "",
            videoUrl = "https://example.com/video",
        )
        val spaceVideo = distributedVideo(
            id = "d",
            title = "space",
            sortOrder = 3,
            embedHtml = "   ",
            vimeoUrl = "\n\t",
            videoUrl = "https://example.com/video",
        )

        assertEquals(VideoPlayerSource.Html("<iframe />"), videoPlayerSource(embedVideo))
        assertEquals(VideoPlayerSource.Url("https://example.com/vimeo"), videoPlayerSource(vimeoOnlyVideo))
        assertEquals(VideoPlayerSource.Url("https://example.com/video"), videoPlayerSource(urlOnlyVideo))
        assertEquals(VideoPlayerSource.Url("https://example.com/video"), videoPlayerSource(spaceVideo))
    }

    private fun distributedVideo(
        id: String,
        title: String,
        sortOrder: Int,
        embedHtml: String = "",
        vimeoUrl: String = "",
        videoUrl: String = "",
        isMembersOnly: Boolean = false,
        isPremium: Boolean = false,
    ): DistributedVideo = DistributedVideo(
        id = id,
        communityId = "org-1",
        videoTitle = title,
        description = "",
        embedHtml = embedHtml,
        videoUrl = videoUrl,
        vimeoUrl = vimeoUrl,
        providerVideoId = "",
        videoType = "distributed_vimeo",
        thumbnailUrl = "",
        isPremium = isPremium,
        createdAt = null,
        updatedAt = null,
        isPublished = true,
        isMembersOnly = isMembersOnly,
        sortOrder = sortOrder,
    )
}
