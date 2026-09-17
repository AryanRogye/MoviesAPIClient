//
//  EmbeddedMovieView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import WebKit

@Observable
@MainActor
final class EmbeddedMovieViewModel {
    private(set) var error: String?
    var showError: Bool = false
    var estimatedProgress: Double = 0
    var isLoading: Bool = false

    func handleLoadFailure(_ error: Error) {
        let error = error as NSError
        if error.domain == NSURLErrorDomain,
           error.code == NSURLErrorCancelled {
            return
        }

        showError = true
        self.error = error.localizedDescription
        return
    }
}

public struct EmbeddedMovieView: View {

    @Environment(PlaybackSession.self) var playbackSession
    @Environment(BlockingService.self) var blockingService
    @State var vm: EmbeddedMovieViewModel = .init()
    let url: URL

    public init(url: URL) {
        self.url = url
    }

    public var body: some View {
        WebView(
            vm: vm,
            playbackSession: playbackSession,
            blockingService: blockingService,
            url: url
        )
        .overlay(alignment: .topLeading) {
            loadingProgress
        }
    }

    @ViewBuilder
    private var loadingProgress: some View {
        if vm.isLoading {
            GeometryReader { geo in
                Capsule()
                    .fill(.yellow)
                    .frame(
                        width: geo.size.width * vm.estimatedProgress,
                        height: 3
                    )
                    .animation(
                        .easeInOut(duration: 0.25),
                        value: vm.estimatedProgress
                    )
            }
            .frame(height: 3)
        }
    }
}

#if os(iOS)
private typealias Representable = UIViewRepresentable

#elseif os(macOS)
private typealias Representable = NSViewRepresentable
#endif

/// Bridges a `WKWebView` from `WebViewModel` into SwiftUI.
struct WebView: Representable {

    @Bindable var vm: EmbeddedMovieViewModel
    @Bindable var playbackSession: PlaybackSession
    let blockingService: BlockingService
    let url: URL

    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView {

        if let webView = playbackSession.webView {
            blockingService.attachNetworkFilters(to: webView)
            context.coordinator.attach(to: webView)
            return webView
        }

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

        playbackSession.webView = wv

        blockingService.attachNetworkFilters(to: wv)
        context.coordinator.attach(to: wv)
        wv.load(url)
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
    #elseif os(macOS)
    func makeNSView(context: Context) -> WKWebView {

        if let webView = playbackSession.webView {
            blockingService.attachNetworkFilters(to: webView)
            context.coordinator.attach(to: webView)
            return webView
        }

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

        playbackSession.webView = wv

        blockingService.attachNetworkFilters(to: wv)
        context.coordinator.attach(to: wv)
        wv.load(url)
        return wv

    }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
    #endif

    func makeCoordinator() -> Coordinator {
        Coordinator(vm: vm)
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
        private var vm: EmbeddedMovieViewModel

        private var kvoTokens: [NSKeyValueObservation] = []

        init(vm: EmbeddedMovieViewModel) {
            self.vm = vm
            super.init()
        }

        func attach(to webView: WKWebView) {
            webView.navigationDelegate = self
            webView.uiDelegate = self

            kvoTokens.append(
                webView.observe(\.isLoading, options: .new) { [weak self] _, change in
                    guard let self else { return }
                    let val = change.newValue ?? false
                    Task { @MainActor in self.vm.isLoading = val }
                }
            )
            kvoTokens.append(
                webView.observe(\.estimatedProgress, options: .new) { [weak self] _, change in
                    guard let self else { return }
                    let val = change.newValue ?? 0
                    Task { @MainActor in self.vm.estimatedProgress = val }
                }
            )
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
                vm.handleLoadFailure(error)
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                vm.handleLoadFailure(error)
            }
        }

        /// Navigation Did Finish
        /// - Tag: WKNavigationDelegate_didFinishNavigation
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                vm.showError = false
            }
        }
    }
}
