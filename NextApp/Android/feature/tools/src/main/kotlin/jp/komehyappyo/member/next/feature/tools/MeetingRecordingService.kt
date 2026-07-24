package jp.komehyappyo.member.next.feature.tools

import android.content.Context
import android.content.Intent
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.ModelDownloadListener
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.io.File
import java.util.Locale

interface SpeechTranscriptionProvider {
    val transcript: String
    val notice: String?
    var onTranscriptChanged: ((String) -> Unit)?
    fun start()
    fun stop()
    fun release()
}

class AndroidOnDeviceTranscriptionProvider(
    private val context: Context,
) : SpeechTranscriptionProvider {
    override var transcript: String = ""
        private set
    override var notice: String? = null
        private set
    override var onTranscriptChanged: ((String) -> Unit)? = null

    private var recognizer: SpeechRecognizer? = null
    private var finalizedTranscript: String = ""
    private var isRunning = false
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun start() {
        stop()
        transcript = ""
        finalizedTranscript = ""
        notice = null
        isRunning = true
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        ) {
            notice =
                "この端末では端末内文字起こしを利用できません。録音後に手入力できます。"
            return
        }
        recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context).also { speech ->
            speech.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) = Unit
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() = Unit
                override fun onEvent(eventType: Int, params: Bundle?) = Unit

                override fun onError(error: Int) {
                    if (!isRunning) return
                    notice = recognitionErrorNotice(error)
                    if (error == SpeechRecognizer.ERROR_NO_MATCH ||
                        error == SpeechRecognizer.ERROR_SPEECH_TIMEOUT ||
                        error == SpeechRecognizer.ERROR_RECOGNIZER_BUSY
                    ) {
                        mainHandler.postDelayed(
                            {
                                if (isRunning && recognizer === speech) {
                                    startListening(speech)
                                }
                            },
                            RECOGNITION_RETRY_DELAY_MILLIS,
                        )
                    }
                }

                override fun onResults(results: Bundle?) {
                    updateText(results, isFinal = true)
                    if (isRunning) startListening(speech)
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    updateText(partialResults, isFinal = false)
                }
            })
            checkJapaneseModelAndStart(speech)
        }
    }

    override fun stop() {
        isRunning = false
        mainHandler.removeCallbacksAndMessages(null)
        recognizer?.stopListening()
        recognizer?.destroy()
        recognizer = null
    }

    override fun release() {
        stop()
    }

    private fun startListening(speech: SpeechRecognizer) {
        runCatching { speech.startListening(recognitionIntent()) }
            .onFailure { error ->
                notice =
                    "端末内の文字起こしを開始できませんでした（${error.javaClass.simpleName}）。" +
                    "録音は保存されるため、停止後に手入力できます。"
            }
    }

    private fun recognitionIntent(): Intent =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.JAPAN.toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }

    private fun checkJapaneseModelAndStart(speech: SpeechRecognizer) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            startListening(speech)
            return
        }
        val intent = recognitionIntent()
        speech.checkRecognitionSupport(
            intent,
            context.mainExecutor,
            object : RecognitionSupportCallback {
                override fun onSupportResult(recognitionSupport: RecognitionSupport) {
                    if (!isRunning || recognizer !== speech) return
                    when {
                        recognitionSupport.installedOnDeviceLanguages.any(
                            ::isJapaneseLanguageTag,
                        ) -> {
                            notice = null
                            startListening(speech)
                        }

                        recognitionSupport.pendingOnDeviceLanguages.any(
                            ::isJapaneseLanguageTag,
                        ) -> {
                            notice =
                                "日本語の端末内文字起こしモデルを準備中です。" +
                                "今回の録音は保存されます。"
                        }

                        recognitionSupport.supportedOnDeviceLanguages.any(
                            ::isJapaneseLanguageTag,
                        ) -> {
                            downloadJapaneseModel(speech, intent)
                        }

                        else -> {
                            notice =
                                "この端末の音声認識サービスは日本語の端末内文字起こしに" +
                                "対応していません。録音停止後に手入力できます。"
                        }
                    }
                }

                override fun onError(error: Int) {
                    if (!isRunning || recognizer !== speech) return
                    if (error == SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT) {
                        notice =
                            "日本語モデルの状態を確認できないため、文字起こしを試行します。"
                        startListening(speech)
                    } else {
                        notice = recognitionSupportErrorNotice(error)
                    }
                }
            },
        )
    }

    private fun downloadJapaneseModel(speech: SpeechRecognizer, intent: Intent) {
        notice = "日本語の端末内文字起こしモデルをダウンロードします。"
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            speech.triggerModelDownload(intent)
            return
        }
        speech.triggerModelDownload(
            intent,
            context.mainExecutor,
            object : ModelDownloadListener {
                override fun onProgress(completedPercent: Int) {
                    if (!isRunning || recognizer !== speech) return
                    notice =
                        "日本語の端末内文字起こしモデルを準備中です（$completedPercent%）。"
                }

                override fun onSuccess() {
                    if (!isRunning || recognizer !== speech) return
                    notice = null
                    startListening(speech)
                }

                override fun onScheduled() {
                    if (!isRunning || recognizer !== speech) return
                    notice =
                        "日本語モデルのダウンロードを予約しました。" +
                        "今回の録音は保存されます。"
                }

                override fun onError(error: Int) {
                    if (!isRunning || recognizer !== speech) return
                    notice =
                        "日本語モデルを準備できませんでした（エラー $error）。" +
                        "録音停止後に手入力できます。"
                }
            },
        )
    }

    private fun updateText(results: Bundle?, isFinal: Boolean) {
        val values = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val latest = values?.firstOrNull()?.trim().orEmpty()
        if (latest.isEmpty()) return

        if (isFinal) {
            finalizedTranscript = listOf(finalizedTranscript, latest)
                .filter(String::isNotBlank)
                .joinToString("\n")
        }
        transcript = if (isFinal) {
            finalizedTranscript
        } else {
            listOf(finalizedTranscript, latest)
                .filter(String::isNotBlank)
                .joinToString("\n")
        }
        notice = null
        onTranscriptChanged?.invoke(transcript)
    }

    companion object {
        private const val RECOGNITION_RETRY_DELAY_MILLIS = 500L
    }
}

internal fun isJapaneseLanguageTag(value: String): Boolean =
    Locale.forLanguageTag(value.replace('_', '-')).language == Locale.JAPANESE.language

internal fun recognitionSupportErrorNotice(error: Int): String =
    when (error) {
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ->
            "日本語はこの端末の音声認識サービスに対応していません。"

        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ->
            "日本語の端末内文字起こしモデルが利用できません。"

        else ->
            "日本語モデルを確認できませんでした（エラー $error）。"
    } + "録音は保存されるため、停止後に手入力できます。"

internal fun recognitionErrorNotice(error: Int): String =
    when (error) {
        SpeechRecognizer.ERROR_AUDIO ->
            "音声入力を文字起こしへ渡せませんでした"

        SpeechRecognizer.ERROR_CLIENT ->
            "アプリから音声認識サービスを開始できませんでした"

        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS ->
            "文字起こしに必要なマイク権限がありません"

        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ->
            "日本語はこの端末の音声認識サービスに対応していません"

        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ->
            "日本語の端末内文字起こしモデルが利用できません"

        SpeechRecognizer.ERROR_NO_MATCH ->
            "音声を聞き取れませんでした。文字起こしを再開します"

        SpeechRecognizer.ERROR_RECOGNIZER_BUSY ->
            "音声認識サービスが使用中です。文字起こしを再開します"

        SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
            "発話を確認できませんでした。文字起こしを再開します"

        SpeechRecognizer.ERROR_TOO_MANY_REQUESTS ->
            "音声認識の利用回数が端末の上限に達しました"

        SpeechRecognizer.ERROR_NETWORK,
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
        ->
            "端末内音声認識サービスで通信エラーが発生しました"

        SpeechRecognizer.ERROR_SERVER,
        SpeechRecognizer.ERROR_SERVER_DISCONNECTED,
        ->
            "端末内音声認識サービスとの接続が切れました"

        else ->
            "端末内文字起こしを継続できませんでした"
    } + "（エラー $error）。録音は保存されます。"

class MeetingRecordingService(
    private val context: Context,
    private val transcriptionProvider: SpeechTranscriptionProvider =
        AndroidOnDeviceTranscriptionProvider(context),
) {
    var isRecording: Boolean = false
        private set
    val transcript: String
        get() = transcriptionProvider.transcript
    val transcriptionNotice: String?
        get() = transcriptionProvider.notice
    var onInterrupted: (() -> Unit)? = null
    var onTranscriptChanged: ((String) -> Unit)?
        get() = transcriptionProvider.onTranscriptChanged
        set(value) {
            transcriptionProvider.onTranscriptChanged = value
        }

    private var recorder: MediaRecorder? = null

    fun start(file: File) {
        check(!isRecording)
        file.parentFile?.mkdirs()
        val value = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(context)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }
        value.setAudioSource(MediaRecorder.AudioSource.MIC)
        // ADTS is a streaming container, so audio written before an unexpected
        // process termination remains recoverable without a final MP4 index.
        value.setOutputFormat(MediaRecorder.OutputFormat.AAC_ADTS)
        value.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        value.setAudioEncodingBitRate(96_000)
        value.setAudioSamplingRate(44_100)
        value.setOutputFile(file.absolutePath)
        value.setOnErrorListener { _, _, _ -> onInterrupted?.invoke() }
        value.prepare()
        value.start()
        recorder = value
        isRecording = true
        transcriptionProvider.start()
    }

    fun stop(): String {
        if (!isRecording) return transcript
        transcriptionProvider.stop()
        runCatching { recorder?.stop() }
        recorder?.release()
        recorder = null
        isRecording = false
        return transcript
    }

    fun release() {
        stop()
        transcriptionProvider.release()
    }
}
