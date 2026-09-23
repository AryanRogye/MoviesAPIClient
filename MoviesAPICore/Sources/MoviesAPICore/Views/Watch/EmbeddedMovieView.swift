//
//  EmbeddedMovieView.swift
//  MoviesAPIClient
//
//  Created by Aryan Rogye on 9/14/26.
//

import SwiftUI
import WebKit
import ProccesInfo

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

struct TimeInfo: Decodable {
    var currentTime: Double
    var duration: Double
}

struct EmbeddedMovieView: View {

    @Environment(PlaybackSession.self) var playbackSession
    @Environment(BlockingService.self) var blockingService
    @State var vm: EmbeddedMovieViewModel = .init()
    let url: URL
    var onTimeInfo: (TimeInfo) -> Void = { _ in }
    var iFrameLogs: (String) -> Void = { _ in }
    var navigationLogs: (String) -> Void = { _ in }

    var body: some View {
        WebView(
            vm: vm,
            playbackSession: playbackSession,
            blockingService: blockingService,
            url: url,
            onTimeInfo: onTimeInfo,
            iFrameLogs: iFrameLogs,
            navigationLogs: navigationLogs
        )
        .overlay(alignment: .topLeading) {
            loadingProgress
        }
        .alert(isPresented: $vm.showError) {
            Alert(
                title: Text("Error"),
                message: Text("\(vm.error, default: "Unknown Error")")
            )
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
    let onTimeInfo: (TimeInfo) -> Void
    let iFrameLogs: (String) -> Void
    let navigationLogs: (String) -> Void

#if os(iOS)
    func makeUIView(context: Context) -> WKWebView {
        return makeWebView(context: context)
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
#elseif os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        return makeWebView(context: context)
    }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
#endif

    private func makeWebView(context: Context) -> WKWebView {

        if let webView = playbackSession.webView {
            blockingService.attachNetworkFilters(to: webView)
            context.coordinator.attach(to: webView)
            return webView
        }

        let config = WKWebViewConfiguration()
#if os(iOS)
        config.allowsInlineMediaPlayback = false
        config.allowsPictureInPictureMediaPlayback = true
        config.preferences.isElementFullscreenEnabled = false
#else
        config.preferences.isElementFullscreenEnabled = true
#endif
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()
        blockingService.attachPopupBlocking(to: config)

        let wv = WKWebView(frame: .zero, configuration: config)
#if DEBUG
        wv.isInspectable = true
#endif
        wv.allowsBackForwardNavigationGestures = false

#if os(iOS)
        wv.isOpaque = true
        wv.layer.drawsAsynchronously = true
        wv.layer.shouldRasterize = false
        wv.scrollView.decelerationRate = .normal
#elseif os(macOS)
        wv.layer?.drawsAsynchronously = true
        wv.layer?.shouldRasterize = false
#endif

        blockingService.attachNetworkFilters(to: wv)
        context.coordinator.attach(to: wv)
#if os(iOS)
        playbackSession.webView = wv
#endif
        wv.load(url)
        return wv
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            vm: vm,
            onTimeInfo: onTimeInfo,
            iFrameLogs: iFrameLogs,
            navigationLogs: navigationLogs
        )
    }

    // MARK: – Web View Delegates

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        private var videoFrame: WKFrameInfo?
        private var vm: EmbeddedMovieViewModel
        let onTimeInfo: (TimeInfo) -> Void
        let iFrameLogs: (String) -> Void
        let navigationLogs: (String) -> Void
        var pid: pid_t?

        private var kvoTokens: [NSKeyValueObservation] = []

#if os(macOS)
        let memory = WebKitMemory()
        var memoryMonitor: Task<Void, Never>?

        deinit {
            memoryMonitor?.cancel()
            memoryMonitor = nil
        }
#endif

        init(
            vm: EmbeddedMovieViewModel,
            onTimeInfo: @escaping (TimeInfo) -> Void,
            iFrameLogs: @escaping (String) -> Void,
            navigationLogs: @escaping (String) -> Void
        ) {
            self.vm = vm
            self.onTimeInfo = onTimeInfo
            self.iFrameLogs = iFrameLogs
            self.navigationLogs = navigationLogs
            super.init()
        }

        func attach(to webView: WKWebView) {
            webView.navigationDelegate = self
            webView.uiDelegate = self
            kvoTokens.removeAll()
            startObservation(with: webView)
            attachWatcher(to: webView)
            beginMonitoringPID()
        }
    }
}

// MARK: - WKWebView Conformance
extension WebView.Coordinator {
    /// Apply the same restriction if WebKit delivers a new-window request
    /// directly to the UI delegate. Never load arbitrary scripted pop-ups.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        navigationLogs(
            "Attempted To Navigate To \(navigationAction.request.url?.absoluteString ?? "Unknown URL")"
        )
        return nil
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
            loadPID(for: webView)
        }
    }

}

// MARK: - Observation
extension WebView.Coordinator {
    internal func startObservation(with webView: WKWebView) {
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
}

// MARK: - MacOS WebView Performance
extension WebView.Coordinator {

    private func loadPID(for webView: WKWebView) {
#if os(macOS)
        self.pid = memory.webProcessIdentifier(for: webView)
#endif
    }

    private func beginMonitoringPID() {
#if os(macOS)
        memoryMonitor?.cancel()

        var lastCPUTime: UInt64 = 0


        memoryMonitor = Task.detached(priority: .background) { [weak self] in

            func getMemory(for pid: pid_t) -> Double {
                let mem = getMemoryForProcess(pid)
                let gb = Double(mem) / 1_000_000_000
                return gb
            }

            func getCPUUsage(for pid: pid_t) -> (Int32, Double) {
                let processThreadInfo = getCPUInfo(pid)

                let cpuTime = processThreadInfo.cpuTime
                if lastCPUTime != 0 {
                    let delta = cpuTime - lastCPUTime
                    let cpuSeconds = Double(delta) / 1_000_000_000
                    let cpuPercent = (cpuSeconds / 5.0) * 100.0
                    lastCPUTime = cpuTime
                    return (processThreadInfo.count, cpuPercent)
                }

                lastCPUTime = cpuTime
                return (processThreadInfo.count, 0);
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self else { return }
                guard let pid = await pid else { continue }

                let mem = getMemory(for: pid)
                print("\(pid) Memory: \(mem)GB")

                let (threadCount, cpu) = getCPUUsage(for: pid)
                print("CPU: \(String(format: "%.2f", cpu))%")
                print("Thread Count: \(threadCount)")
            }
        }
#endif
    }

#if DEBUG
    private func findProcessMethods(_ object: AnyObject) {
        var cls: AnyClass? = object_getClass(object)

        while let current = cls {
            print("\n=== \(NSStringFromClass(current)) ===")

            var count: UInt32 = 0

            if let methods = class_copyMethodList(current, &count) {
                defer { free(methods) }

                for i in 0..<Int(count) {
                    let selector = method_getName(methods[i])
                    let name = NSStringFromSelector(selector)

                    if name.localizedCaseInsensitiveContains("process") ||
                        name.localizedCaseInsensitiveContains("pid") {
                        print(name)
                    }
                }
            }

            cls = class_getSuperclass(current)
        }
    }
#endif
}

// MARK: - Dismantle
extension WebView.Coordinator {
    static func dismantleNSView(_ nsView: WKWebView, coordinator: WebView.Coordinator) {
        Self.dismantleView(nsView, coordinator: coordinator)
    }
    static func dismantleUIView(_ uiView: WKWebView, coordinator: WebView.Coordinator) {
        Self.dismantleView(uiView, coordinator: coordinator)
    }

    private static func dismantleView(_ view: WKWebView, coordinator: WebView.Coordinator) {
        // Split changes can mount a new wrapper around the same WKWebView
        // before SwiftUI dismantles the old one. Only its current owner may
        // remove delegates, message handlers, or the active video styling.
        guard view.navigationDelegate === coordinator else { return }
        view.navigationDelegate = nil
        view.uiDelegate = nil

        view.configuration.userContentController.removeScriptMessageHandler(forName: "iframeDebug")
        view.configuration.userContentController.removeScriptMessageHandler(forName: "iframeLog")
    }
}

// MARK: - Scripting
extension WebView.Coordinator: WKScriptMessageHandler {

    internal func attachWatcher(to webView: WKWebView) {
        guard let monitorUrl = Bundle.module.url(
            forResource: "monitorIFrame",
            withExtension: "js"
        ) else {
            print("Couldnt find monitorIFrame.js")
            return
        }
        guard let monitorText = try? String(contentsOf: monitorUrl, encoding: .utf8) else {
            print("Couldnt convert monitorIFrame.js to text")
            return
        }

        let monitorScript = WKUserScript(
            source: monitorText,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        webView.configuration.userContentController.addUserScript(monitorScript)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "iframeDebug")
        webView.configuration.userContentController.add(self, name: "iframeDebug")


        guard let iFrameLoggerUrl = Bundle.module.url(
            forResource: "IFrameLogger",
            withExtension: "js"
        ) else {
            print("Couldnt Find IFrameLogger.js")
            return
        }
        guard let iFrameLoggerText = try? String(contentsOf: iFrameLoggerUrl, encoding: .utf8) else {
            print("Couldnt convert IFrameLogger.js to text")
            return
        }

        let loggerScript = WKUserScript(
            source: iFrameLoggerText,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )

        webView.configuration.userContentController.addUserScript(loggerScript)
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "iframeLog")
        webView.configuration.userContentController.add(self, name: "iframeLog")
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        switch message.name {
        case "iframeLog":
            guard let dictionary = message.body as? [String: Any] else {
                print("Couldnt convert message body into dictionary")
                return
            }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary) else {
                print("Coudlnt convert dictionary into json data")
                return
            }

            iFrameLogs(String(data: jsonData, encoding: .utf8) ?? "Unable To Decode message.body")

        case "iframeDebug":

            guard let dictionary = message.body as? [String: Any] else {
                print("Couldnt convert message body into dictionary")
                return
            }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: dictionary) else {
                print("Coudlnt convert dictionary into json data")
                return
            }

            iFrameLogs(String(data: jsonData, encoding: .utf8) ?? "Unable To Decode message.body")

            do {
                let timeInfo = try JSONDecoder().decode(TimeInfo.self, from: jsonData)
                onTimeInfo(timeInfo)
            } catch {
                print("Error Converting iframeDebug body into `TimeInfo`: \(error.localizedDescription)")
            }
        default:
            break
        }
    }
}
