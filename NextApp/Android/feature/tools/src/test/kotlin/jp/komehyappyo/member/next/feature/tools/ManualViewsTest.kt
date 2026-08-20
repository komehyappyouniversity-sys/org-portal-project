package jp.komehyappyo.member.next.feature.tools

import jp.komehyappyo.member.next.core.data.ManualRepository
import jp.komehyappyo.member.next.core.model.Manual
import jp.komehyappyo.member.next.core.session.AppSession
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

@OptIn(ExperimentalCoroutinesApi::class)
class ManualViewsTest {
    private val dispatcher = StandardTestDispatcher()

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(dispatcher)
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun loadPublishesRepositoryManuals() = runTest(dispatcher) {
        val expected = listOf(sampleManual())
        val model = ManualFeatureModel(FakeManualRepository(Result.success(expected)), AppSession())

        model.load()
        dispatcher.scheduler.advanceUntilIdle()

        assertEquals(expected, model.state.value.manuals)
        assertTrue(model.state.value.hasLoaded)
        assertFalse(model.state.value.isLoading)
        assertNull(model.state.value.errorMessage)
    }

    @Test
    fun loadFailureUsesSharedErrorMessage() = runTest(dispatcher) {
        val model = ManualFeatureModel(
            FakeManualRepository(Result.failure(IllegalStateException("network"))),
            AppSession(),
        )

        model.load()
        dispatcher.scheduler.advanceUntilIdle()

        assertTrue(model.state.value.manuals.isEmpty())
        assertEquals("マニュアルを読み込めませんでした。", model.state.value.errorMessage)
        assertTrue(model.state.value.hasLoaded)
    }

    private fun sampleManual() = Manual(
        id = "shared",
        communityId = null,
        title = "タイトル",
        body = "本文",
        sortOrder = 1,
        isPublished = true,
    )
}

private class FakeManualRepository(
    private val result: Result<List<Manual>>,
) : ManualRepository {
    override suspend fun manuals(communityId: String?, idToken: String?): Result<List<Manual>> =
        result
}
