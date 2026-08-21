package jp.komehyappyo.member.next.feature.community

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.media.app.NotificationCompat.MediaStyle
import androidx.media.session.MediaButtonReceiver
import jp.komehyappyo.member.next.core.data.FirebaseRestCommunityRepository
import jp.komehyappyo.member.next.core.model.RadioPlaybackInterruptionPolicy
import jp.komehyappyo.member.next.core.model.RadioPlaybackPresentation
import jp.komehyappyo.member.next.core.model.RadioPlaybackRecord
import jp.komehyappyo.member.next.core.model.RadioPlaybackRecordPolicy
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.Instant

data class RadioPlaybackServiceState(
    val programId: String? = null,
    val isPlaying: Boolean = false,
    val positionSeconds: Long = 0,
    val errorMessage: String? = null,
)

object RadioPlaybackServiceStateStore {
    private val mutableState = MutableStateFlow(RadioPlaybackServiceState())
    val state = mutableState.asStateFlow()

    internal fun update(value: RadioPlaybackServiceState) {
        mutableState.value = value
    }
}

class RadioPlaybackService : Service(), AudioManager.OnAudioFocusChangeListener {
    private data class PersistenceContext(
        val projectId: String,
        val idToken: String,
        val record: RadioPlaybackRecord,
    )

    private val handler = Handler(Looper.getMainLooper())
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private lateinit var audioManager: AudioManager
    private lateinit var audioFocusRequest: AudioFocusRequest
    private lateinit var mediaSession: MediaSessionCompat
    private var mediaPlayer: MediaPlayer? = null
    private var persistenceContext: PersistenceContext? = null
    private var persistenceJob: Job? = null
    private var currentTitle = "インターネットラジオ"
    private var prepared = false
    private var playWhenPrepared = false
    private var resumeOnFocusGain = false

    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                resumeOnFocusGain = false
                pausePlayback()
            }
        }
    }

    private val periodicSave = object : Runnable {
        override fun run() {
            if (isActuallyPlaying()) persistPosition()
            handler.postDelayed(this, SAVE_INTERVAL_MILLIS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        audioManager = getSystemService(AudioManager::class.java)
        audioFocusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            .setOnAudioFocusChangeListener(this)
            .build()
        createNotificationChannel()
        configureMediaSession()
        ContextCompat.registerReceiver(
            this,
            noisyReceiver,
            IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        handler.postDelayed(periodicSave, SAVE_INTERVAL_MILLIS)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == Intent.ACTION_MEDIA_BUTTON) {
            MediaButtonReceiver.handleIntent(mediaSession, intent)
            return START_NOT_STICKY
        }
        when (intent?.action) {
            ACTION_START -> runCatching { startProgram(intent) }
                .onFailure { finishStoppedState(PLAYBACK_ERROR_MESSAGE) }
            ACTION_PLAY -> resumePlayback()
            ACTION_PAUSE -> {
                resumeOnFocusGain = false
                pausePlayback()
            }
            ACTION_STOP -> stopPlayback()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onAudioFocusChange(focusChange: Int) {
        if (RadioPlaybackInterruptionPolicy.shouldPause(focusChange)) {
            resumeOnFocusGain = focusChange != AudioManager.AUDIOFOCUS_LOSS &&
                isActuallyPlaying()
            pausePlayback(abandonFocus = focusChange == AudioManager.AUDIOFOCUS_LOSS)
        } else if (RadioPlaybackInterruptionPolicy.shouldResume(resumeOnFocusGain, focusChange)) {
            resumeOnFocusGain = false
            resumePlayback()
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(periodicSave)
        runCatching { unregisterReceiver(noisyReceiver) }
        persistPosition()
        releasePlayer()
        RadioPlaybackServiceStateStore.update(RadioPlaybackServiceState())
        mediaSession.release()
        super.onDestroy()
    }

    private fun configureMediaSession() {
        mediaSession = MediaSessionCompat(this, "RadioPlayback").apply {
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() = resumePlayback()
                override fun onPause() {
                    resumeOnFocusGain = false
                    pausePlayback()
                }
                override fun onStop() = stopPlayback()
            })
            isActive = true
        }
    }

    private fun startProgram(intent: Intent) {
        val programId = requireNotNull(intent.getStringExtra(EXTRA_PROGRAM_ID))
        val audioUrl = requireNotNull(intent.getStringExtra(EXTRA_AUDIO_URL))
        val userId = requireNotNull(intent.getStringExtra(EXTRA_USER_ID))
        val token = requireNotNull(intent.getStringExtra(EXTRA_ID_TOKEN))
        val projectId = requireNotNull(intent.getStringExtra(EXTRA_PROJECT_ID))
        currentTitle = intent.getStringExtra(EXTRA_TITLE).orEmpty().ifBlank {
            "インターネットラジオ"
        }
        val startPositionSeconds = intent.getLongExtra(EXTRA_POSITION_SECONDS, 0).coerceAtLeast(0)
        persistPosition()
        releasePlayer()
        persistenceContext = PersistenceContext(
            projectId = projectId,
            idToken = token,
            record = RadioPlaybackRecord(
                userId = userId,
                programId = programId,
                lastPositionSeconds = startPositionSeconds,
                playCount = intent.getIntExtra(EXTRA_PLAY_COUNT, 1).coerceAtLeast(1),
                lastPlayedAt = Instant.now(),
            ),
        )
        prepared = false
        playWhenPrepared = true
        updateStore(isPlaying = false, positionSeconds = startPositionSeconds)
        updateMediaMetadata()
        startInForeground(notification(isPlaying = false))

        mediaPlayer = MediaPlayer().apply {
            setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            setDataSource(audioUrl)
            setOnPreparedListener { player ->
                prepared = true
                if (startPositionSeconds > 0) {
                    player.seekTo((startPositionSeconds * 1_000).coerceAtMost(Int.MAX_VALUE.toLong()).toInt())
                }
                if (playWhenPrepared) resumePlayback()
            }
            setOnCompletionListener {
                persistPosition(positionOverride = 0)
                finishStoppedState()
            }
            setOnErrorListener { _, _, _ ->
                persistPosition()
                finishStoppedState(PLAYBACK_ERROR_MESSAGE)
                true
            }
            prepareAsync()
        }
        persistPosition(positionOverride = startPositionSeconds)
    }

    private fun resumePlayback() {
        playWhenPrepared = true
        val player = mediaPlayer ?: return
        if (!prepared) return
        if (audioManager.requestAudioFocus(audioFocusRequest) != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            return
        }
        runCatching { player.start() }.onSuccess {
            updateStore(isPlaying = true)
            updatePlaybackState(PlaybackStateCompat.STATE_PLAYING)
            updateNotification(isPlaying = true)
        }
    }

    private fun pausePlayback(abandonFocus: Boolean = true) {
        playWhenPrepared = false
        val player = mediaPlayer ?: return
        if (prepared && player.isPlaying) runCatching { player.pause() }
        if (abandonFocus) audioManager.abandonAudioFocusRequest(audioFocusRequest)
        updateStore(isPlaying = false)
        updatePlaybackState(PlaybackStateCompat.STATE_PAUSED)
        updateNotification(isPlaying = false)
        persistPosition()
    }

    private fun stopPlayback() {
        persistPosition()
        finishStoppedState()
    }

    private fun finishStoppedState(errorMessage: String? = null) {
        releasePlayer()
        persistenceContext = null
        RadioPlaybackServiceStateStore.update(
            RadioPlaybackServiceState(errorMessage = errorMessage),
        )
        updatePlaybackState(PlaybackStateCompat.STATE_STOPPED, positionSeconds = 0)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun releasePlayer() {
        audioManager.abandonAudioFocusRequest(audioFocusRequest)
        mediaPlayer?.setOnPreparedListener(null)
        mediaPlayer?.setOnCompletionListener(null)
        mediaPlayer?.setOnErrorListener(null)
        mediaPlayer?.release()
        mediaPlayer = null
        prepared = false
        playWhenPrepared = false
    }

    private fun persistPosition(positionOverride: Long? = null) {
        val context = persistenceContext ?: return
        val position = positionOverride ?: currentPositionSeconds()
        val record = RadioPlaybackRecordPolicy.updatingPosition(
            existing = context.record,
            positionSeconds = position,
            at = Instant.now(),
        )
        persistenceContext = context.copy(record = record)
        updateStore(isActuallyPlaying(), position)
        val previousJob = persistenceJob
        persistenceJob = serviceScope.launch {
            previousJob?.join()
            FirebaseRestCommunityRepository(context.projectId)
                .saveRadioPlaybackRecord(record, context.idToken)
        }
    }

    private fun currentPositionSeconds(): Long = if (prepared) {
        runCatching { mediaPlayer?.currentPosition?.div(1_000L) ?: 0 }.getOrDefault(0)
    } else {
        persistenceContext?.record?.lastPositionSeconds ?: 0
    }

    private fun isActuallyPlaying(): Boolean = prepared &&
        runCatching { mediaPlayer?.isPlaying == true }.getOrDefault(false)

    private fun updateStore(
        isPlaying: Boolean,
        positionSeconds: Long = currentPositionSeconds(),
    ) {
        RadioPlaybackServiceStateStore.update(
            RadioPlaybackServiceState(
                programId = persistenceContext?.record?.programId,
                isPlaying = isPlaying,
                positionSeconds = positionSeconds.coerceAtLeast(0),
            ),
        )
    }

    private fun updateMediaMetadata() {
        mediaSession.setMetadata(
            MediaMetadataCompat.Builder()
                .putString(MediaMetadataCompat.METADATA_KEY_TITLE, currentTitle)
                .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, "インターネットラジオ")
                .build(),
        )
        updatePlaybackState(PlaybackStateCompat.STATE_BUFFERING)
    }

    private fun updatePlaybackState(
        playbackState: Int,
        positionSeconds: Long = currentPositionSeconds(),
    ) {
        mediaSession.setPlaybackState(
            PlaybackStateCompat.Builder()
                .setActions(
                    PlaybackStateCompat.ACTION_PLAY or
                        PlaybackStateCompat.ACTION_PAUSE or
                        PlaybackStateCompat.ACTION_PLAY_PAUSE or
                        PlaybackStateCompat.ACTION_STOP,
                )
                .setState(
                    playbackState,
                    positionSeconds.coerceAtLeast(0) * 1_000,
                    if (playbackState == PlaybackStateCompat.STATE_PLAYING) 1f else 0f,
                )
                .build(),
        )
    }

    private fun notification(isPlaying: Boolean): Notification {
        val toggleAction = if (isPlaying) ACTION_PAUSE else ACTION_PLAY
        val toggleIcon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val toggleLabel = if (isPlaying) {
            RadioPlaybackPresentation.PAUSE_ACTION
        } else {
            RadioPlaybackPresentation.RESUME_ACTION
        }
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = launchIntent?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE)
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(currentTitle)
            .setContentText(RadioPlaybackPresentation.status(isPlaying))
            .setContentIntent(contentIntent)
            .setDeleteIntent(servicePendingIntent(ACTION_STOP, 3))
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOnlyAlertOnce(true)
            .setOngoing(isPlaying)
            .addAction(toggleIcon, toggleLabel, servicePendingIntent(toggleAction, 1))
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                RadioPlaybackPresentation.STOP_ACTION,
                servicePendingIntent(ACTION_STOP, 2),
            )
            .setStyle(
                MediaStyle()
                    .setMediaSession(mediaSession.sessionToken)
                    .setShowActionsInCompactView(0, 1)
                    .setShowCancelButton(true)
                    .setCancelButtonIntent(servicePendingIntent(ACTION_STOP, 4)),
            )
            .build()
    }

    private fun servicePendingIntent(action: String, requestCode: Int): PendingIntent =
        PendingIntent.getService(
            this,
            requestCode,
            Intent(this, RadioPlaybackService::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private fun startInForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(isPlaying: Boolean) {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, notification(isPlaying))
    }

    private fun createNotificationChannel() {
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "ラジオ再生",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "インターネットラジオの再生操作"
            },
        )
    }

    companion object {
        const val ACTION_START = "jp.komehyappyo.member.next.radio.START"
        const val ACTION_PLAY = "jp.komehyappyo.member.next.radio.PLAY"
        const val ACTION_PAUSE = "jp.komehyappyo.member.next.radio.PAUSE"
        const val ACTION_STOP = "jp.komehyappyo.member.next.radio.STOP"
        const val EXTRA_PROGRAM_ID = "program_id"
        const val EXTRA_TITLE = "title"
        const val EXTRA_AUDIO_URL = "audio_url"
        const val EXTRA_POSITION_SECONDS = "position_seconds"
        const val EXTRA_PLAY_COUNT = "play_count"
        const val EXTRA_USER_ID = "user_id"
        const val EXTRA_ID_TOKEN = "id_token"
        const val EXTRA_PROJECT_ID = "project_id"

        private const val CHANNEL_ID = "radio_playback"
        private const val NOTIFICATION_ID = 3901
        private const val SAVE_INTERVAL_MILLIS = 30_000L
        private const val PLAYBACK_ERROR_MESSAGE =
            "再生できませんでした。ネットワーク接続と音声URLをご確認ください。"
    }
}
