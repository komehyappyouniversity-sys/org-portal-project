//
//  MemberVideoPlayerView.swift
//  blog.k100
//

import SwiftUI
import WebKit

struct MemberVideoPlayerView: View {
    let video: MemberVideoItem

    @StateObject private var watchLogStore = MemberVideoWatchLogStore()

    private var organizationId: String {
        OrganizationConfig.organizationId
    }

    var body: some View {
        VStack(spacing: 0) {
            if !video.embedURL.isEmpty {
                VimeoPlayerWebView(
                    embedURL: video.embedURL,
                    onPlayStarted: {
                        watchLogStore.recordVideoPlayStarted(
                            organizationId: organizationId,
                            videoId: video.id,
                            videoTitle: video.title
                        )
                    },
                    onProgress: { current, duration in
                        watchLogStore.updatePlaybackProgress(
                            organizationId: organizationId,
                            videoId: video.id,
                            videoTitle: video.title,
                            currentPositionSeconds: current,
                            durationSeconds: duration
                        )
                    },
                    onCompleted: { duration in
                        watchLogStore.recordCompleted(
                            organizationId: organizationId,
                            videoId: video.id,
                            videoTitle: video.title,
                            durationSeconds: duration
                        )
                    }
                )
                .ignoresSafeArea(edges: .bottom)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundColor(.orange)

                    Text("動画URLを開けません")
                        .font(.headline)

                    Text("Vimeo動画IDまたはURLを確認してください。")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                .padding()
            }
        }
        .navigationTitle(video.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            watchLogStore.recordVideoOpened(
                organizationId: organizationId,
                videoId: video.id,
                videoTitle: video.title
            )
        }
    }
}

private struct VimeoPlayerWebView: UIViewRepresentable {
    let embedURL: String
    let onPlayStarted: () -> Void
    let onProgress: (_ currentSeconds: Double, _ durationSeconds: Double) -> Void
    let onCompleted: (_ durationSeconds: Double) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "vimeoEvent")

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isScrollEnabled = true

        webView.loadHTMLString(makeHTML(embedURL: embedURL), baseURL: nil)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onPlayStarted: onPlayStarted,
            onProgress: onProgress,
            onCompleted: onCompleted
        )
    }

    private func makeHTML(embedURL: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            html, body {
              margin: 0;
              padding: 0;
              background: #000;
              height: 100%;
              width: 100%;
              overflow: hidden;
            }
            iframe {
              width: 100%;
              height: 100%;
              border: 0;
            }
          </style>
          <script src="https://player.vimeo.com/api/player.js"></script>
        </head>
        <body>
          <iframe
            id="vimeo-player"
            src="\(embedURL)"
            allow="autoplay; fullscreen; picture-in-picture"
            allowfullscreen>
          </iframe>

          <script>
            const iframe = document.getElementById('vimeo-player');
            const player = new Vimeo.Player(iframe);

            let lastProgressSentAt = 0;

            function send(type, payload) {
              window.webkit.messageHandlers.vimeoEvent.postMessage({
                type: type,
                payload: payload || {}
              });
            }

            player.on('play', function() {
              send('play', {});
            });

            player.on('timeupdate', function(data) {
              const now = Date.now();

              if (now - lastProgressSentAt > 10000) {
                lastProgressSentAt = now;
                send('progress', {
                  seconds: data.seconds || 0,
                  duration: data.duration || 0
                });
              }
            });

            player.on('ended', function(data) {
              send('ended', {
                duration: data.duration || 0
              });
            });
          </script>
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let onPlayStarted: () -> Void
        let onProgress: (_ currentSeconds: Double, _ durationSeconds: Double) -> Void
        let onCompleted: (_ durationSeconds: Double) -> Void

        private var didRecordPlayStarted = false

        init(
            onPlayStarted: @escaping () -> Void,
            onProgress: @escaping (_ currentSeconds: Double, _ durationSeconds: Double) -> Void,
            onCompleted: @escaping (_ durationSeconds: Double) -> Void
        ) {
            self.onPlayStarted = onPlayStarted
            self.onProgress = onProgress
            self.onCompleted = onCompleted
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                let body = message.body as? [String: Any],
                let type = body["type"] as? String
            else {
                return
            }

            let payload = body["payload"] as? [String: Any] ?? [:]

            switch type {
            case "play":
                if !didRecordPlayStarted {
                    didRecordPlayStarted = true
                    onPlayStarted()
                }

            case "progress":
                let seconds = payload["seconds"] as? Double ?? 0
                let duration = payload["duration"] as? Double ?? 0
                onProgress(seconds, duration)

            case "ended":
                let duration = payload["duration"] as? Double ?? 0
                onCompleted(duration)

            default:
                break
            }
        }
    }
}
