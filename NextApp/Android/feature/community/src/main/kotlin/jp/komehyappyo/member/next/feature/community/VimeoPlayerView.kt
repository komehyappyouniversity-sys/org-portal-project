package jp.komehyappyo.member.next.feature.community

import android.annotation.SuppressLint
import android.graphics.Color
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.viewinterop.AndroidView
import kotlinx.coroutines.delay

enum class VimeoPlaybackAction {
    Play,
    Pause,
    Stop,
    Seek,
    SeekAndPlay,
}

data class VimeoPlaybackCommand(
    val action: VimeoPlaybackAction,
    val requestId: Int,
    val positionSeconds: Double? = null,
)

@SuppressLint("SetJavaScriptEnabled", "JavascriptInterface")
@Composable
fun VimeoPlayerView(
    videoId: String,
    playbackCommand: VimeoPlaybackCommand?,
    initialPlaybackSeconds: Double,
    onTimeChanged: (Double) -> Unit,
    onPlaybackStarted: () -> Unit = {},
    onPlaybackCompleted: () -> Unit = {},
    isLandscape: Boolean,
    modifier: Modifier = Modifier,
) {
    var webView by remember(videoId) { mutableStateOf<WebView?>(null) }
    var isReady by remember(videoId) { mutableStateOf(false) }
    var isLoading by remember(videoId) { mutableStateOf(true) }
    var errorMessage by remember(videoId) { mutableStateOf<String?>(null) }
    val safeVideoId = remember(videoId) { videoId.filter(Char::isDigit) }

    AndroidView(
        modifier = modifier,
        factory = { context ->
            FrameLayout(context).apply {
                setBackgroundColor(Color.BLACK)
                val loading = ProgressBar(context).apply {
                    tag = "vimeo-loading"
                    layoutParams = FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        ViewGroup.LayoutParams.WRAP_CONTENT,
                        Gravity.CENTER,
                    )
                }
                val error = TextView(context).apply {
                    tag = "vimeo-error"
                    setTextColor(Color.WHITE)
                    textSize = 14f
                    gravity = Gravity.CENTER
                    setPadding(24, 24, 24, 24)
                    layoutParams = FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT,
                    )
                    visibility = View.GONE
                }
                val playerWebView = WebView(context).apply {
                    tag = "vimeo-webview"
                    setBackgroundColor(Color.BLACK)
                    settings.javaScriptEnabled = true
                    settings.domStorageEnabled = true
                    settings.mediaPlaybackRequiresUserGesture = false
                    settings.loadWithOverviewMode = true
                    settings.useWideViewPort = true
                    webChromeClient = WebChromeClient()
                    webViewClient = WebViewClient()
                    addJavascriptInterface(
                        VimeoJavascriptBridge(
                            onReady = {
                                post {
                                    isReady = true
                                    isLoading = false
                                    errorMessage = null
                                }
                            },
                            onTimeChanged = { seconds ->
                                post { onTimeChanged(seconds) }
                            },
                            onPlaybackStarted = {
                                post { onPlaybackStarted() }
                            },
                            onPlaybackCompleted = {
                                post { onPlaybackCompleted() }
                            },
                            onError = { message ->
                                post {
                                    isLoading = false
                                    errorMessage = message
                                }
                            },
                        ),
                        "AndroidVimeo",
                    )
                    layoutParams = FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT,
                    )
                    if (safeVideoId.isBlank()) {
                        errorMessage = "動画IDが不正です。"
                    } else {
                        loadDataWithBaseURL(
                            "https://player.vimeo.com/",
                            vimeoPlayerHtml(safeVideoId, initialPlaybackSeconds),
                            "text/html",
                            "utf-8",
                            null,
                        )
                    }
                }
                addView(playerWebView)
                addView(loading)
                addView(error)
                webView = playerWebView
            }
        },
        update = { container ->
            val loading = container.findViewWithTag<View>("vimeo-loading")
            val error = container.findViewWithTag<TextView>("vimeo-error")
            loading.visibility = if (isLoading) View.VISIBLE else View.GONE
            error?.let { errorView ->
                errorView.text = errorMessage.orEmpty()
                errorView.visibility = if (errorMessage == null) View.GONE else View.VISIBLE
            }
        },
        onRelease = { container ->
            (container.findViewWithTag<View>("vimeo-webview") as? WebView)?.apply {
                removeJavascriptInterface("AndroidVimeo")
                stopLoading()
                destroy()
            }
            webView = null
        },
    )

    LaunchedEffect(webView, playbackCommand?.requestId) {
        val command = playbackCommand ?: return@LaunchedEffect
        val playerWebView = webView ?: return@LaunchedEffect
        val seconds = (command.positionSeconds ?: 0.0).coerceAtLeast(0.0)
        val script = when (command.action) {
            VimeoPlaybackAction.Play -> "window.vimeoCommand('play', 0);"
            VimeoPlaybackAction.Pause -> "window.vimeoCommand('pause', 0);"
            VimeoPlaybackAction.Stop -> "window.vimeoCommand('stop', 0);"
            VimeoPlaybackAction.Seek -> "window.vimeoCommand('seek', $seconds);"
            VimeoPlaybackAction.SeekAndPlay -> "window.vimeoCommand('seekAndPlay', $seconds);"
        }
        playerWebView.evaluateJavascript(script, null)
    }

    LaunchedEffect(webView, isReady) {
        while (webView != null) {
            if (isReady) webView?.evaluateJavascript("window.vimeoReportTime();", null)
            delay(500)
        }
    }
}

private class VimeoJavascriptBridge(
    private val onReady: () -> Unit,
    private val onTimeChanged: (Double) -> Unit,
    private val onPlaybackStarted: () -> Unit,
    private val onPlaybackCompleted: () -> Unit,
    private val onError: (String) -> Unit,
) {
    @JavascriptInterface
    fun ready() = onReady()

    @JavascriptInterface
    fun timeChanged(seconds: Double) = onTimeChanged(seconds)

    @JavascriptInterface
    fun playbackStarted() = onPlaybackStarted()

    @JavascriptInterface
    fun playbackCompleted() = onPlaybackCompleted()

    @JavascriptInterface
    fun error(message: String) = onError(message)
}

private fun vimeoPlayerHtml(videoId: String, initialPlaybackSeconds: Double): String {
    val initialSeconds = initialPlaybackSeconds.coerceAtLeast(0.0)
    return """
        <!doctype html>
        <html><head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>html,body,#vimeo-player{margin:0;width:100%;height:100%;background:#000;overflow:hidden}</style>
          <script src="https://player.vimeo.com/api/player.js"></script>
        </head><body><div id="vimeo-player"></div>
        <script>
          const player = new Vimeo.Player('vimeo-player', {
            id: $videoId, autoplay: false, autopause: true, controls: true,
            dnt: true, playsinline: true, responsive: true
          });
          let lastTime = 0;
          player.ready().then(function() {
            if ($initialSeconds > 0) player.setCurrentTime($initialSeconds);
            AndroidVimeo.ready();
          }).catch(function(error) { AndroidVimeo.error(error.message || 'Vimeoプレーヤーを準備できませんでした。'); });
          player.on('timeupdate', function(data) {
            lastTime = data.seconds || 0;
            AndroidVimeo.timeChanged(lastTime);
          });
          player.on('play', function() { AndroidVimeo.playbackStarted(); });
          player.on('ended', function(data) {
            lastTime = (data && data.seconds) || lastTime;
            AndroidVimeo.timeChanged(lastTime);
            AndroidVimeo.playbackCompleted();
          });
          player.on('error', function(error) { AndroidVimeo.error(error.message || 'Vimeoの再生に失敗しました。'); });
          window.vimeoReportTime = function() { AndroidVimeo.timeChanged(lastTime); };
          window.vimeoCommand = function(action, seconds) {
            if (action === 'play') player.play();
            if (action === 'pause') player.pause();
            if (action === 'stop') player.pause().then(function(){ return player.setCurrentTime(0); });
            if (action === 'seek') player.setCurrentTime(seconds);
            if (action === 'seekAndPlay') player.setCurrentTime(seconds).then(function(){ return player.play(); });
          };
        </script></body></html>
    """.trimIndent()
}
