import SwiftUI
import WebKit

/// Hosts the bundled `index.html` web app in a `WKWebView`.
///
/// Uses the persistent default website data store so the web app's
/// `localStorage` survives app launches.
struct WebAppView: UIViewRepresentable {
    let fileURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        // Let the trophy video play inside the page instead of going full screen.
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // The page asks its host for a "downloads" capability to save the results
        // screenshot. Provide one that hands the file to the native share sheet.
        let contentController = configuration.userContentController
        contentController.addUserScript(WKUserScript(
            source: Self.downloadsBridgeScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        contentController.addScriptMessageHandler(
            context.coordinator,
            contentWorld: .page,
            name: Coordinator.downloadsHandlerName
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        // Match the page's dark green so nothing white shows while loading or
        // when scrolling past the edges.
        let pageGreen = UIColor(red: 0x13 / 255, green: 0x2A / 255, blue: 0x20 / 255, alpha: 1)
        webView.isOpaque = false
        webView.backgroundColor = pageGreen
        webView.scrollView.backgroundColor = pageGreen
        webView.underPageBackgroundColor = pageGreen
        // The page pads itself with env(safe-area-inset-*), so don't inset it again.
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        #if DEBUG
        // Allows debugging the page from Safari's Develop menu.
        webView.isInspectable = true
        #endif

        // Grant read access to the containing folder so relative references resolve.
        webView.loadFileURL(fileURL, allowingReadAccessTo: fileURL.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController
            .removeScriptMessageHandler(forName: Coordinator.downloadsHandlerName, contentWorld: .page)
    }

    /// Defines `window.claude.use('downloads')`, the API the page expects for saving
    /// files. `save({ filename, data })` sends the Blob to native code as base64 and
    /// throws an error with `code: 'declined'` if the share sheet is dismissed.
    /// Any other capability resolves to `null`.
    private static let downloadsBridgeScript = """
    (() => {
      const downloads = {
        async save({ filename, data }) {
          const base64 = await new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(String(reader.result).split(',')[1] || '');
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(data);
          });
          const result = await window.webkit.messageHandlers.\(Coordinator.downloadsHandlerName)
            .postMessage({ filename, base64 });
          if (result === 'declined') {
            const error = new Error('declined');
            error.code = 'declined';
            throw error;
          }
        }
      };
      window.claude = { use: async (name) => (name === 'downloads' ? downloads : null) };
    })();
    """

    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandlerWithReply {
        static let downloadsHandlerName = "downloads"

        // MARK: Downloads

        /// Writes the file sent by the page to a temporary folder and presents the
        /// share sheet, where "Save Image" puts it in Photos.
        /// Replies `"saved"`, or `"declined"` if the sheet is dismissed.
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) async -> (Any?, String?) {
            guard
                let body = message.body as? [String: Any],
                let base64 = body["base64"] as? String,
                let data = Data(base64Encoded: base64),
                let webView = message.webView
            else {
                return (nil, "Invalid file data")
            }

            let filename = Self.safeFilename(from: body["filename"] as? String)
            let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            do {
                try data.write(to: fileURL, options: .atomic)
            } catch {
                return (nil, "Couldn't write the file")
            }

            let completed = await withCheckedContinuation { continuation in
                let sheet = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                sheet.completionWithItemsHandler = { _, completed, _, _ in
                    continuation.resume(returning: completed)
                }
                // iPad shows the sheet as a popover, which needs an anchor.
                sheet.popoverPresentationController?.sourceView = webView
                sheet.popoverPresentationController?.sourceRect = CGRect(
                    x: webView.bounds.midX, y: webView.bounds.midY, width: 0, height: 0
                )
                present(sheet, from: webView) { continuation.resume(returning: false) }
            }
            try? FileManager.default.removeItem(at: fileURL)
            return (completed ? "saved" : "declined", nil)
        }

        /// Returns just the last path component of the page's requested filename,
        /// so the page can't write outside the temp folder, or a default name if
        /// nothing usable was given.
        static func safeFilename(from requested: String?) -> String {
            let name = ((requested ?? "") as NSString).lastPathComponent
            return name.isEmpty || name == "/" || name == "." || name == ".." ? "creek-golf-results.png" : name
        }

        // MARK: Navigation

        /// Keeps the app on the bundled page; external links open in Safari.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }
            if navigationAction.navigationType == .linkActivated, !url.isFileURL {
                await UIApplication.shared.open(url)
                return .cancel
            }
            return .allow
        }

        /// iOS can shut the page's process down to save memory while the app is
        /// in the background (phone in a pocket between holes). Reload it, so the
        /// app comes back to the saved round instead of a blank screen.
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }

        // MARK: JavaScript dialogs
        // WKWebView ignores alert(), confirm() and prompt() unless the app presents them.

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo
        ) async {
            await withCheckedContinuation { continuation in
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    continuation.resume()
                })
                present(alert, from: webView) { continuation.resume() }
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo
        ) async -> Bool {
            await withCheckedContinuation { continuation in
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    continuation.resume(returning: false)
                })
                alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                    continuation.resume(returning: true)
                })
                present(alert, from: webView) { continuation.resume(returning: false) }
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo
        ) async -> String? {
            await withCheckedContinuation { continuation in
                let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
                alert.addTextField { $0.text = defaultText }
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                    continuation.resume(returning: nil)
                })
                alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak alert] _ in
                    continuation.resume(returning: alert?.textFields?.first?.text)
                })
                present(alert, from: webView) { continuation.resume(returning: nil) }
            }
        }

        /// Presents an alert or sheet from the top-most view controller, or calls
        /// `onFailure` if there is nothing to present from.
        private func present(_ alert: UIViewController, from webView: WKWebView, onFailure: () -> Void) {
            guard var presenter = webView.window?.rootViewController else {
                onFailure()
                return
            }
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(alert, animated: true)
        }
    }
}
