//
//  EmbeddedMovieView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import WebKit

struct EmbeddedMovieView: View {

    @Environment(BlockingService.self) var blockingService
    let url: URL

    var body: some View {
        WebView(
            blockingService: blockingService,
            url: url
        )
    }
}

#if os(iOS)
private typealias Representable = UIViewRepresentable

#elseif os(macOS)
private typealias Representable = NSViewRepresentable
#endif

/// Bridges a `WKWebView` from `WebViewModel` into SwiftUI.
struct WebView: Representable {


    let blockingService: BlockingService
    let url: URL

    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView {

        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.allowsInlineMediaPlayback = true
        config.allowsPictureInPictureMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()

        blockingService.attachPopupBlocking(to: config)

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = false
        wv.isOpaque = true
        wv.layer.drawsAsynchronously = true
        wv.layer.shouldRasterize = false
        wv.scrollView.decelerationRate = .normal

        blockingService.attachNetworkFilters(to: wv)
        context.coordinator.attach(to: wv)
        wv.load(url)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
    #elseif os(macOS)
    func makeNSView(context: Context) -> WKWebView {

        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()
        /// Important to allow to go into fullscreen
        config.preferences.isElementFullscreenEnabled = true

        blockingService.attachPopupBlocking(to: config)

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.allowsBackForwardNavigationGestures = false
        wv.layer?.drawsAsynchronously = true
        wv.layer?.shouldRasterize = false

        blockingService.attachNetworkFilters(to: wv)
        context.coordinator.attach(to: wv)
        wv.load(url)
        return wv

    }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    #endif

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        // Split changes can mount a new wrapper around the same WKWebView
        // before SwiftUI dismantles the old one. Only its current owner may
        // remove delegates, message handlers, or the active video styling.
        guard uiView.navigationDelegate === coordinator else { return }
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
    }

    // MARK: – Web View Delegates

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        private var videoFrame: WKFrameInfo?

        override init() {
            super.init()
        }

        func attach(to webView: WKWebView) {
            webView.navigationDelegate = self
            webView.uiDelegate = self
        }

        /// Turns user-tapped universal links into programmatic web view loads.
        /// This keeps associated links, such as x.com, from opening their app.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // A missing target is a new-window request. Only promote actual
            // links from the page; window.open() and embedded ad pop-ups must
            // never replace the current tab, even when triggered by a tap.
            if navigationAction.targetFrame == nil {
                decisionHandler(.cancel)
                if Self.canOpenInCurrentTab(navigationAction) {
                    webView.load(navigationAction.request)
                }
                return
            }

            guard navigationAction.navigationType == .linkActivated,
                  navigationAction.targetFrame?.isMainFrame == true,
                  Self.isWebRequest(navigationAction.request) else {
                decisionHandler(.allow)
                return
            }

            decisionHandler(.cancel)
            webView.load(navigationAction.request)
        }

        /// Apply the same restriction if WebKit delivers a new-window request
        /// directly to the UI delegate. Never load arbitrary scripted pop-ups.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil,
                  Self.canOpenInCurrentTab(navigationAction) else { return nil }
            webView.load(navigationAction.request)
            return nil
        }

        private static func canOpenInCurrentTab(_ action: WKNavigationAction) -> Bool {
            action.navigationType == .linkActivated
            && action.sourceFrame.isMainFrame
            && isWebRequest(action.request)
        }

        private static func isWebRequest(_ request: URLRequest) -> Bool {
            guard let scheme = request.url?.scheme?.lowercased() else { return false }
            return scheme == "http" || scheme == "https"
        }

        /// Errors
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
//                viewModel.handleLoadFailure(error)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
//                viewModel.handleLoadFailure(error)
            }
        }

        /// Navigation Did Finish
        /// - Tag: WKNavigationDelegate_didFinishNavigation
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
//                viewModel.showError = false
//                viewModel.refreshFaviconURL()
            }
        }
    }
}
