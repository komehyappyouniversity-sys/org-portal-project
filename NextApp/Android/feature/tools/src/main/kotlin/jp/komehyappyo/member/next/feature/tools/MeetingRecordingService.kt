package jp.komehyappyo.member.next.feature.tools

import android.content.Context
import android.content.Intent
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
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
                    if (isRunning) {
                        notice =
                            "端末内の文字起こしを継続できません。録音は保存されます。"
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
            startListening(speech)
        }
    }

    override fun stop() {
        isRunning = false
        recognizer?.stopListening()
        recognizer?.destroy()
        recognizer = null
    }

    override fun release() {
        stop()
    }

    private fun startListening(speech: SpeechRecognizer) {
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.JAPAN.toLanguageTag())
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }
        runCatching { speech.startListening(intent) }
            .onFailure {
                notice =
                    "端末内の文字起こしを開始できません。録音後に手入力できます。"
            }
    }

    private fun updateText(results: Bundle?, isFinal: Boolean) {
        val values = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val latest = values?.firstOrNull()?.trim().orEmpty()
        if (latest.isNotEmpty()) {
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
            onTranscriptChanged?.invoke(transcript)
        }
    }
}

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
