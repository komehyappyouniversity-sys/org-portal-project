package jp.komehyappyo.member.next.feature.tools

import android.content.Context
import android.content.Intent
import android.media.AudioFormat
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.speech.ModelDownloadListener
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.annotation.RequiresApi
import java.io.File
import java.util.Locale

interface SpeechTranscriptionProvider {
    val transcript: String
    val notice: String?
    val isTranscribing: Boolean
    var onTranscriptChanged: ((String) -> Unit)?
    var onTranscriptionStateChanged: ((Boolean) -> Unit)?
    fun transcribe(file: File)
    fun cancel()
    fun release()
}

class AndroidOnDeviceTranscriptionProvider(
    private val context: Context,
) : SpeechTranscriptionProvider {
    override var transcript: String = ""
        private set
    override var notice: String? = null
        private set
    override var isTranscribing: Boolean = false
        private set
    override var onTranscriptChanged: ((String) -> Unit)? = null
    override var onTranscriptionStateChanged: ((Boolean) -> Unit)? = null

    private var recognizer: SpeechRecognizer? = null
    private var audioInput: ParcelFileDescriptor? = null
    private var audioOutput: ParcelFileDescriptor? = null
    private var decoderThread: Thread? = null
    private var sourceFile: File? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pcmStreamer = SavedAudioPcmStreamer()

    override fun transcribe(file: File) {
        cancel()
        transcript = ""
        notice = null
        sourceFile = file
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            finishWithNotice(
                "このAndroidバージョンでは保存音声の端末内文字起こしを利用できません。" +
                    "録音を再生しながら手入力できます。",
            )
            return
        }
        if (!file.exists() || file.length() == 0L) {
            finishWithNotice("文字起こしする録音ファイルを確認できませんでした。")
            return
        }
        if (
            !SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        ) {
            finishWithNotice(
                "この端末では端末内文字起こしを利用できません。" +
                    "録音を再生しながら手入力できます。",
            )
            return
        }
        setTranscribing(true)
        notice = "保存した録音を文字起こしする準備をしています。"
        recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(context).also { speech ->
            speech.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) = Unit
                override fun onBeginningOfSpeech() = Unit
                override fun onRmsChanged(rmsdB: Float) = Unit
                override fun onBufferReceived(buffer: ByteArray?) = Unit
                override fun onEndOfSpeech() = Unit
                override fun onEvent(eventType: Int, params: Bundle?) = Unit

                override fun onError(error: Int) {
                    if (!isTranscribing) return
                    finishWithNotice(recognitionErrorNotice(error))
                }

                override fun onResults(results: Bundle?) {
                    updateText(results)
                    if (transcript.isBlank()) {
                        finishWithNotice(
                            "録音から音声を聞き取れませんでした。録音は保存されています。",
                        )
                    } else {
                        notice = "文字起こしが完了しました。内容を確認・編集してください。"
                        finish()
                    }
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    updateText(partialResults)
                }
            })
            checkJapaneseModelAndStart(speech, file)
        }
    }

    override fun cancel() {
        mainHandler.removeCallbacksAndMessages(null)
        decoderThread?.interrupt()
        decoderThread = null
        runCatching { audioOutput?.close() }
        runCatching { audioInput?.close() }
        audioOutput = null
        audioInput = null
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
        sourceFile = null
        setTranscribing(false)
    }

    override fun release() {
        cancel()
    }

    private fun startSavedAudioRecognition(speech: SpeechRecognizer, file: File) {
        runCatching {
            val format = pcmStreamer.inspect(file)
            val pipe = ParcelFileDescriptor.createPipe()
            audioInput = pipe[0]
            audioOutput = pipe[1]
            val intent = recognitionIntent().apply {
                putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, pipe[0])
                putExtra(
                    RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING,
                    AudioFormat.ENCODING_PCM_16BIT,
                )
                putExtra(
                    RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE,
                    format.sampleRate,
                )
                putExtra(
                    RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT,
                    format.channelCount,
                )
            }
            notice = "保存した録音を端末内で文字起こししています。"
            speech.startListening(intent)
            decoderThread = Thread(
                {
                    val writeSide = audioOutput ?: return@Thread
                    runCatching {
                        ParcelFileDescriptor.AutoCloseOutputStream(writeSide).use { output ->
                            pcmStreamer.stream(file, output)
                        }
                        mainHandler.postDelayed(
                            {
                                if (isTranscribing && sourceFile == file) {
                                    finishWithNotice(
                                        "端末内音声認識から結果を取得できませんでした。" +
                                            "録音は保存されています。再実行するか手入力してください。",
                                    )
                                }
                            },
                            RESULT_TIMEOUT_AFTER_AUDIO_MILLIS,
                        )
                    }.onFailure { error ->
                        mainHandler.post {
                            if (isTranscribing && sourceFile == file) {
                                finishWithNotice(
                                    "録音音声を文字起こしへ渡せませんでした" +
                                        "（${error.javaClass.simpleName}）。録音は保存されています。",
                                )
                            }
                        }
                    }
                },
                "meeting-audio-decoder",
            ).apply { start() }
        }
            .onFailure { error ->
                finishWithNotice(
                    "保存音声の文字起こしを開始できませんでした" +
                        "（${error.javaClass.simpleName}）。録音は保存されています。",
                )
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

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun checkJapaneseModelAndStart(speech: SpeechRecognizer, file: File) {
        val intent = recognitionIntent()
        speech.checkRecognitionSupport(
            intent,
            context.mainExecutor,
            object : RecognitionSupportCallback {
                override fun onSupportResult(recognitionSupport: RecognitionSupport) {
                    if (!isTranscribing || recognizer !== speech) return
                    when {
                        recognitionSupport.installedOnDeviceLanguages.any(
                            ::isJapaneseLanguageTag,
                        ) -> {
                            notice = null
                            startSavedAudioRecognition(speech, file)
                        }

                        recognitionSupport.pendingOnDeviceLanguages.any(
                            ::isJapaneseLanguageTag,
                        ) -> {
                            notice =
                                "日本語の端末内文字起こしモデルを準備中です。" +
                                "録音は保存されています。準備完了後に再度お試しください。"
                            finish()
                        }

                        recognitionSupport.supportedOnDeviceLanguages.any(
                            ::isJapaneseLanguageTag,
                        ) -> {
                            downloadJapaneseModel(speech, intent, file)
                        }

                        else -> {
                            notice =
                                "この端末の音声認識サービスは日本語の端末内文字起こしに" +
                                "対応していません。録音を再生しながら手入力できます。"
                            finish()
                        }
                    }
                }

                override fun onError(error: Int) {
                    if (!isTranscribing || recognizer !== speech) return
                    if (error == SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT) {
                        notice =
                            "日本語モデルの状態を確認できないため、文字起こしを試行します。"
                        startSavedAudioRecognition(speech, file)
                    } else {
                        finishWithNotice(recognitionSupportErrorNotice(error))
                    }
                }
            },
        )
    }

    @RequiresApi(Build.VERSION_CODES.TIRAMISU)
    private fun downloadJapaneseModel(
        speech: SpeechRecognizer,
        intent: Intent,
        file: File,
    ) {
        notice = "日本語の端末内文字起こしモデルをダウンロードします。"
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            speech.triggerModelDownload(intent)
            notice =
                "日本語モデルのダウンロードを開始しました。" +
                    "録音は保存されています。準備完了後に再度お試しください。"
            finish()
            return
        }
        speech.triggerModelDownload(
            intent,
            context.mainExecutor,
            object : ModelDownloadListener {
                override fun onProgress(completedPercent: Int) {
                    if (!isTranscribing || recognizer !== speech) return
                    notice =
                        "日本語の端末内文字起こしモデルを準備中です（$completedPercent%）。"
                }

                override fun onSuccess() {
                    if (!isTranscribing || recognizer !== speech) return
                    notice = null
                    startSavedAudioRecognition(speech, file)
                }

                override fun onScheduled() {
                    if (!isTranscribing || recognizer !== speech) return
                    notice =
                        "日本語モデルのダウンロードを予約しました。" +
                        "録音は保存されています。準備完了後に再度お試しください。"
                    finish()
                }

                override fun onError(error: Int) {
                    if (!isTranscribing || recognizer !== speech) return
                    finishWithNotice(
                        "日本語モデルを準備できませんでした（エラー $error）。" +
                            "録音を再生しながら手入力できます。",
                    )
                }
            },
        )
    }

    private fun updateText(results: Bundle?) {
        val values = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val latest = values?.firstOrNull()?.trim().orEmpty()
        if (latest.isEmpty()) return

        transcript = latest
        notice = null
        onTranscriptChanged?.invoke(transcript)
    }

    private fun finishWithNotice(value: String) {
        notice = value
        finish()
    }

    private fun finish() {
        decoderThread?.interrupt()
        decoderThread = null
        runCatching { audioOutput?.close() }
        runCatching { audioInput?.close() }
        audioOutput = null
        audioInput = null
        recognizer?.destroy()
        recognizer = null
        sourceFile = null
        setTranscribing(false)
    }

    private fun setTranscribing(value: Boolean) {
        if (isTranscribing == value) return
        isTranscribing = value
        onTranscriptionStateChanged?.invoke(value)
    }

    private companion object {
        const val RESULT_TIMEOUT_AFTER_AUDIO_MILLIS = 30_000L
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
    } + "録音は保存されています。再実行するか、録音を再生しながら手入力できます。"

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
            "保存した録音から音声を聞き取れませんでした"

        SpeechRecognizer.ERROR_RECOGNIZER_BUSY ->
            "音声認識サービスが使用中です。少し待ってから再実行してください"

        SpeechRecognizer.ERROR_SPEECH_TIMEOUT ->
            "保存した録音から発話を確認できませんでした"

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
    val isTranscribing: Boolean
        get() = transcriptionProvider.isTranscribing
    var onInterrupted: (() -> Unit)? = null
    var onTranscriptChanged: ((String) -> Unit)?
        get() = transcriptionProvider.onTranscriptChanged
        set(value) {
            transcriptionProvider.onTranscriptChanged = value
        }
    var onTranscriptionStateChanged: ((Boolean) -> Unit)?
        get() = transcriptionProvider.onTranscriptionStateChanged
        set(value) {
            transcriptionProvider.onTranscriptionStateChanged = value
        }

    private var recorder: MediaRecorder? = null
    private var recordingFile: File? = null

    fun start(file: File) {
        check(!isRecording)
        transcriptionProvider.cancel()
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
        recordingFile = file
        isRecording = true
    }

    fun stopAndTranscribe(): String {
        if (!isRecording) return transcript
        runCatching { recorder?.stop() }
        recorder?.release()
        recorder = null
        isRecording = false
        recordingFile?.let(transcriptionProvider::transcribe)
        return transcript
    }

    fun transcribe(file: File) {
        check(!isRecording)
        transcriptionProvider.transcribe(file)
    }

    fun release() {
        if (isRecording) {
            runCatching { recorder?.stop() }
            recorder?.release()
            recorder = null
            isRecording = false
        }
        recordingFile = null
        transcriptionProvider.release()
    }
}
