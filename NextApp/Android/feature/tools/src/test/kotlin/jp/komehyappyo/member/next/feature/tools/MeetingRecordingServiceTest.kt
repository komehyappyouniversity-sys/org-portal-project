package jp.komehyappyo.member.next.feature.tools

import android.speech.SpeechRecognizer
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class MeetingRecordingServiceTest {
    @Test
    fun japaneseLanguageTagsRecognizeRegionalAndLegacyFormats() {
        assertTrue(isJapaneseLanguageTag("ja"))
        assertTrue(isJapaneseLanguageTag("ja-JP"))
        assertTrue(isJapaneseLanguageTag("ja_JP"))
        assertFalse(isJapaneseLanguageTag("en-US"))
    }

    @Test
    fun recognitionErrorsIncludeActionableReasonAndNumericCode() {
        val message = recognitionErrorNotice(SpeechRecognizer.ERROR_AUDIO)

        assertTrue(message.contains("音声入力"))
        assertTrue(message.contains("エラー ${SpeechRecognizer.ERROR_AUDIO}"))
        assertTrue(message.contains("録音は保存"))
    }

    @Test
    fun unsupportedJapaneseModelHasSpecificGuidance() {
        val message = recognitionSupportErrorNotice(
            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED,
        )

        assertTrue(message.contains("日本語"))
        assertTrue(message.contains("対応していません"))
        assertTrue(message.contains("手入力"))
    }
}
